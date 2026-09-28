from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import shutil
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping, Sequence
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


AI_SERVICE_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = AI_SERVICE_ROOT.parent
DEFAULT_CONFIG_PATH = Path(__file__).with_name("staged_29_class_config.json")
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SPLITS = ("train", "val", "test")
VERSION_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
CLASS_COMPONENT_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_]*$")
TRACKING_QUERY_KEYS = {"fbclid", "gclid", "mc_cid", "mc_eid"}

CANONICAL_CLASS_ORDER = (
    "Acanthus_ebracteatus",
    "Acanthus_ilicifolius",
    "Aegiceras_corniculatum",
    "Avicennia_alba",
    "Avicennia_marina",
    "Avicennia_officinalis",
    "Avicennia_rumphiana",
    "Bruguiera_cylindrica",
    "Bruguiera_gymnorrhiza",
    "Bruguiera_sexangula",
    "Camptostemon_philippinensis",
    "Ceriops_tagal",
    "Ceriops_zippeliana",
    "Excoecaria_agallocha",
    "Heritiera_littoralis",
    "Lumnitzera_littorea",
    "Lumnitzera_racemosa",
    "Nypa_fruticans",
    "Osbornia_octodonta",
    "Pemphis_acidula",
    "Rhizophora_apiculata",
    "Rhizophora_mucronata",
    "Rhizophora_stylosa",
    "Scyphiphora_hydrophylacea",
    "Sonneratia_alba",
    "Sonneratia_ovata",
    "Xylocarpus_granatum",
    "Xylocarpus_moluccensis",
    "unknown",
)


class DatasetBuildError(RuntimeError):
    """Raised when a staging build would violate a dataset safety rule."""


@dataclass(frozen=True)
class BuildPolicy:
    class_order: tuple[str, ...]
    split_ratios: Mapping[str, float]
    seed: int
    minimum_unique_images_per_class: int
    minimum_source_groups_per_class: int
    require_every_class_in_every_split: bool
    required_approval_status: str
    require_declared_sha256: bool
    require_source_record: bool
    require_rights_or_license: bool
    allowed_input_roots: tuple[Path, ...]
    input_manifests: tuple[Path, ...]
    staging_root: Path


@dataclass(frozen=True)
class ApprovedImage:
    manifest_path: Path
    manifest_row: int
    entry_id: str
    class_name: str
    source_path: Path
    sha256: str
    source: str
    source_record_id: str
    source_record_keys: tuple[str, ...]
    source_record_url: str
    source_image_url: str
    rights_or_license: str
    reviewed_plant_part: str
    approval_status: str


@dataclass(frozen=True)
class DeduplicatedImage:
    representative: ApprovedImage
    lineage: tuple[ApprovedImage, ...]


@dataclass(frozen=True)
class SourceGroup:
    group_id: str
    class_name: str
    images: tuple[DeduplicatedImage, ...]
    source_record_keys: tuple[str, ...]


@dataclass(frozen=True)
class PlannedImage:
    image: ApprovedImage
    lineage: tuple[ApprovedImage, ...]
    split: str
    group_id: str
    source_record_keys: tuple[str, ...]
    relative_path: Path


@dataclass(frozen=True)
class BuildPlan:
    policy: BuildPolicy
    records: tuple[ApprovedImage, ...]
    groups: tuple[SourceGroup, ...]
    images: tuple[PlannedImage, ...]
    errors: tuple[str, ...]
    warnings: tuple[str, ...]
    manifest_stats: Mapping[str, Mapping[str, int]]
    manifest_digests: Mapping[str, str]
    duplicate_rows_removed: int

    @property
    def ready(self) -> bool:
        return not self.errors


class _DisjointSet:
    def __init__(self, size: int) -> None:
        self.parent = list(range(size))
        self.rank = [0] * size

    def find(self, item: int) -> int:
        parent = self.parent[item]
        if parent != item:
            self.parent[item] = self.find(parent)
        return self.parent[item]

    def union(self, left: int, right: int) -> None:
        left_root = self.find(left)
        right_root = self.find(right)
        if left_root == right_root:
            return
        if self.rank[left_root] < self.rank[right_root]:
            left_root, right_root = right_root, left_root
        self.parent[right_root] = left_root
        if self.rank[left_root] == self.rank[right_root]:
            self.rank[left_root] += 1


def _resolve_from_project(value: str, project_root: Path) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = project_root / path
    return path.resolve()


def _is_within(path: Path, roots: Sequence[Path]) -> bool:
    return any(path == root or root in path.parents for root in roots)


def _normalized_class_name(value: str) -> str:
    return "_".join(value.strip().replace("_", " ").split())


def _first_value(row: Mapping[str, str], fields: Sequence[str]) -> str:
    for field in fields:
        value = str(row.get(field) or "").strip()
        if value:
            return value
    return ""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _normalized_url(value: str) -> str:
    try:
        parsed = urlsplit(value.strip())
    except ValueError:
        return value.strip().casefold()
    if not parsed.scheme or not parsed.netloc:
        return value.strip().casefold()
    path = parsed.path.rstrip("/") or "/"
    semantic_query = [
        (key, item)
        for key, item in parse_qsl(parsed.query, keep_blank_values=True)
        if not key.casefold().startswith("utm_")
        and key.casefold() not in TRACKING_QUERY_KEYS
    ]
    query = urlencode(sorted(semantic_query), doseq=True)
    return urlunsplit((parsed.scheme.casefold(), parsed.netloc.casefold(), path, query, ""))


def _relative_or_absolute(path: Path, project_root: Path) -> str:
    try:
        return path.relative_to(project_root).as_posix()
    except ValueError:
        return str(path)


def load_policy(config_path: Path, project_root: Path = PROJECT_ROOT) -> tuple[BuildPolicy, dict]:
    payload = json.loads(config_path.read_text(encoding="utf-8"))
    if payload.get("status") != "staging_only" or payload.get("requires_retraining") is not True:
        raise DatasetBuildError(
            "The 29-class config must remain staging_only and require a new training run."
        )
    class_order = tuple(str(item) for item in payload.get("class_order", []))
    if class_order != CANONICAL_CLASS_ORDER:
        raise DatasetBuildError(
            "The staging config class_order must match the canonical 28 species plus unknown."
        )

    unknown = payload.get("unknown_class") or {}
    expected_unknown_index = len(CANONICAL_CLASS_ORDER) - 1
    if (
        unknown.get("name") != "unknown"
        or unknown.get("index") != expected_unknown_index
    ):
        raise DatasetBuildError(
            f"unknown must be the final class at index {expected_unknown_index}."
        )

    split = payload.get("split") or {}
    if split.get("group_by") != ["sha256", "source_record"]:
        raise DatasetBuildError("The split policy must group by sha256 and source_record.")
    ratios = split.get("ratios") or {}
    split_ratios = {name: float(ratios.get(name, 0.0)) for name in SPLITS}
    if any(value <= 0 for value in split_ratios.values()):
        raise DatasetBuildError("All train, val, and test split ratios must be positive.")
    if abs(sum(split_ratios.values()) - 1.0) > 1e-9:
        raise DatasetBuildError("Split ratios must add up to 1.0.")

    input_policy = payload.get("input_policy") or {}
    if input_policy.get("required_approval_status") != "approved":
        raise DatasetBuildError(
            "The 29-class builder must require approval_status=approved."
        )
    for required_flag in (
        "require_declared_sha256",
        "require_source_record",
        "require_rights_or_license",
    ):
        if input_policy.get(required_flag) is not True:
            raise DatasetBuildError(
                f"The 29-class builder must keep {required_flag}=true."
            )
    readiness = payload.get("readiness") or {}
    allowed_roots = tuple(
        _resolve_from_project(str(item), project_root)
        for item in payload.get("allowed_input_roots", [])
    )
    manifests = tuple(
        _resolve_from_project(str(item), project_root)
        for item in payload.get("input_manifests", [])
    )
    if not allowed_roots:
        raise DatasetBuildError("At least one allowed input root is required.")
    canonical_input_roots = {
        (project_root / "dataset" / "candidates").resolve(),
        (project_root / "dataset" / "raw").resolve(),
    }
    if any(root not in canonical_input_roots for root in allowed_roots):
        raise DatasetBuildError("Allowed input roots are limited to dataset/candidates and dataset/raw.")
    if not manifests:
        raise DatasetBuildError("At least one input manifest is required.")

    staging_value = str(payload.get("staging_root") or "").strip()
    if not staging_value:
        raise DatasetBuildError("staging_root is required.")
    staging_root = _resolve_from_project(staging_value, project_root)
    canonical_staging_root = (project_root / "dataset" / "staging").resolve()
    if staging_root != canonical_staging_root and canonical_staging_root not in staging_root.parents:
        raise DatasetBuildError("staging_root must stay under dataset/staging.")

    minimum_unique_images = int(readiness.get("minimum_unique_images_per_class", 30))
    minimum_source_groups = int(readiness.get("minimum_source_groups_per_class", 3))
    require_all_splits = bool(readiness.get("require_every_class_in_every_split", True))
    if minimum_unique_images < 1:
        raise DatasetBuildError("minimum_unique_images_per_class must be positive.")
    if minimum_source_groups < 1:
        raise DatasetBuildError("minimum_source_groups_per_class must be positive.")
    if require_all_splits and minimum_source_groups < len(SPLITS):
        raise DatasetBuildError(
            "At least three source groups are required when every split must contain every class."
        )

    policy = BuildPolicy(
        class_order=class_order,
        split_ratios=split_ratios,
        seed=int(split.get("seed", 42)),
        minimum_unique_images_per_class=minimum_unique_images,
        minimum_source_groups_per_class=minimum_source_groups,
        require_every_class_in_every_split=require_all_splits,
        required_approval_status=str(
            input_policy.get("required_approval_status", "approved")
        ).casefold(),
        require_declared_sha256=bool(input_policy.get("require_declared_sha256", True)),
        require_source_record=bool(input_policy.get("require_source_record", True)),
        require_rights_or_license=bool(
            input_policy.get("require_rights_or_license", True)
        ),
        allowed_input_roots=allowed_roots,
        input_manifests=manifests,
        staging_root=staging_root,
    )
    return policy, payload


def _read_manifest(
    manifest_path: Path,
    policy: BuildPolicy,
    project_root: Path,
) -> tuple[list[ApprovedImage], list[str], Counter, str]:
    records: list[ApprovedImage] = []
    errors: list[str] = []
    stats: Counter = Counter()

    if not manifest_path.is_file():
        return records, [f"Input manifest does not exist: {manifest_path}"], stats, ""

    manifest_bytes = manifest_path.read_bytes()
    manifest_digest = hashlib.sha256(manifest_bytes).hexdigest()
    with io.StringIO(manifest_bytes.decode("utf-8-sig"), newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            return (
                records,
                [f"Input manifest has no header: {manifest_path}"],
                stats,
                manifest_digest,
            )

        for row_number, row in enumerate(reader, start=2):
            stats["rows"] += 1
            prefix = f"{manifest_path}:{row_number}"
            approval_values = {
                str(row.get(field) or "").strip().casefold()
                for field in ("review_status", "approval_status")
                if str(row.get(field) or "").strip()
            }
            if len(approval_values) > 1:
                stats["invalid_approval_rows"] += 1
                errors.append(
                    f"{prefix}: conflicting review_status/approval_status values: "
                    f"{sorted(approval_values)}"
                )
                continue
            approval = next(iter(approval_values), "")
            if approval != policy.required_approval_status:
                stats["not_approved"] += 1
                continue

            stats["approved_rows"] += 1
            row_errors: list[str] = []

            raw_class_name = _first_value(
                row,
                ("scientific_name", "species_scientific_name", "class_name"),
            )
            class_name = _normalized_class_name(raw_class_name)
            if class_name not in policy.class_order:
                row_errors.append(f"non-canonical class {raw_class_name!r}")

            raw_file_path = _first_value(row, ("file_path", "source_path"))
            source_path: Path | None = None
            if not raw_file_path:
                row_errors.append("missing file_path")
            else:
                source_path = _resolve_from_project(raw_file_path, project_root)
                if not _is_within(source_path, policy.allowed_input_roots):
                    row_errors.append("file_path is outside the allowed candidate/raw roots")
                elif not source_path.is_file():
                    row_errors.append(f"source file does not exist: {raw_file_path}")
                elif source_path.suffix.casefold() not in SUPPORTED_EXTENSIONS:
                    row_errors.append(f"unsupported image extension {source_path.suffix!r}")

            source = _first_value(row, ("source",))
            if not source:
                row_errors.append("missing source")

            source_identifiers = tuple(
                value
                for field in ("source_record_id", "source_group_id", "observation_id")
                if (value := str(row.get(field) or "").strip())
            )
            # Keep the specific record ID as the primary provenance value. Older
            # manifests may only provide a group or observation ID, so retain the
            # previous fallback behavior for those rows.
            source_record_id = _first_value(
                row, ("source_record_id", "source_group_id", "observation_id")
            )
            if policy.require_source_record and not source_identifiers:
                row_errors.append("missing source_record_id/source_group_id/observation_id")

            rights_or_license = _first_value(row, ("license", "permission_status"))
            if policy.require_rights_or_license and not rights_or_license:
                row_errors.append("missing license/permission_status")

            declared_hash = _first_value(row, ("sha256",)).casefold()
            if policy.require_declared_sha256 and not declared_hash:
                row_errors.append("missing declared sha256")
            elif declared_hash and not SHA256_PATTERN.fullmatch(declared_hash):
                row_errors.append("declared sha256 is not 64 lowercase hexadecimal characters")

            reviewed_part = _first_value(row, ("reviewed_plant_part", "plant_part"))
            if "candidate_id" in row and class_name != "unknown" and not reviewed_part:
                row_errors.append("approved candidate is missing reviewed_plant_part")

            actual_hash = ""
            if source_path is not None and source_path.is_file() and not row_errors:
                actual_hash = _sha256(source_path)
                if declared_hash and actual_hash != declared_hash:
                    row_errors.append(
                        f"sha256 mismatch (manifest={declared_hash}, actual={actual_hash})"
                    )

            if row_errors:
                stats["invalid_approved_rows"] += 1
                errors.extend(f"{prefix}: {message}" for message in row_errors)
                continue

            entry_id = _first_value(row, ("candidate_id", "image_id", "entry_id"))
            if not entry_id:
                entry_id = f"{manifest_path.name}:{row_number}"
            source_record_url = _first_value(row, ("source_record_url",))
            normalized_source = " ".join(source.casefold().split())
            # All declared identifiers participate in connected-component grouping.
            # A source_group_id can therefore keep a related photo sequence in one
            # split without replacing each image's unique source_record_id.
            source_record_keys = list(
                dict.fromkeys(
                    f"id::{normalized_source}::{identifier}"
                    for identifier in source_identifiers
                )
            )
            if source_record_url:
                source_record_keys.append(f"url::{_normalized_url(source_record_url)}")
            records.append(
                ApprovedImage(
                    manifest_path=manifest_path.resolve(),
                    manifest_row=row_number,
                    entry_id=entry_id,
                    class_name=class_name,
                    source_path=source_path.resolve(),
                    sha256=actual_hash or declared_hash,
                    source=source,
                    source_record_id=source_record_id,
                    source_record_keys=tuple(source_record_keys),
                    source_record_url=source_record_url,
                    source_image_url=_first_value(row, ("source_image_url",)),
                    rights_or_license=rights_or_license,
                    reviewed_plant_part=reviewed_part,
                    approval_status=approval,
                )
            )
            stats["accepted_rows"] += 1

    return records, errors, stats, manifest_digest


def collect_approved_images(
    manifest_paths: Sequence[Path],
    policy: BuildPolicy,
    project_root: Path = PROJECT_ROOT,
) -> tuple[
    list[ApprovedImage],
    list[str],
    dict[str, Mapping[str, int]],
    dict[str, str],
]:
    records: list[ApprovedImage] = []
    errors: list[str] = []
    manifest_stats: dict[str, Mapping[str, int]] = {}
    manifest_digests: dict[str, str] = {}
    for manifest_path in manifest_paths:
        manifest_records, manifest_errors, stats, manifest_digest = _read_manifest(
            manifest_path.resolve(), policy, project_root.resolve()
        )
        records.extend(manifest_records)
        errors.extend(manifest_errors)
        manifest_key = str(manifest_path.resolve())
        manifest_stats[manifest_key] = dict(stats)
        if manifest_digest:
            manifest_digests[manifest_key] = manifest_digest
    return records, errors, manifest_stats, manifest_digests


def build_source_groups(
    records: Sequence[ApprovedImage],
) -> tuple[list[SourceGroup], list[str], int]:
    if not records:
        return [], [], 0

    disjoint = _DisjointSet(len(records))
    first_by_hash: dict[str, int] = {}
    first_by_record: dict[str, int] = {}
    for index, record in enumerate(records):
        if record.sha256 in first_by_hash:
            disjoint.union(index, first_by_hash[record.sha256])
        else:
            first_by_hash[record.sha256] = index

        for source_record_key in record.source_record_keys:
            if source_record_key in first_by_record:
                disjoint.union(index, first_by_record[source_record_key])
            else:
                first_by_record[source_record_key] = index

    members: defaultdict[int, list[ApprovedImage]] = defaultdict(list)
    for index, record in enumerate(records):
        members[disjoint.find(index)].append(record)

    errors: list[str] = []
    groups: list[SourceGroup] = []
    unique_hash_count = 0
    for component in members.values():
        labels = sorted({record.class_name for record in component})
        hashes = sorted({record.sha256 for record in component})
        if len(labels) != 1:
            errors.append(
                "Conflicting class labels are connected by an exact hash or source record: "
                f"classes={labels}, hashes={hashes[:4]}"
            )
            continue

        representatives: list[DeduplicatedImage] = []
        by_hash: defaultdict[str, list[ApprovedImage]] = defaultdict(list)
        for record in component:
            by_hash[record.sha256].append(record)
        for image_hash in sorted(by_hash):
            candidates = sorted(
                by_hash[image_hash],
                key=lambda item: (
                    str(item.source_path).casefold(),
                    str(item.manifest_path).casefold(),
                    item.manifest_row,
                ),
            )
            representatives.append(
                DeduplicatedImage(
                    representative=candidates[0],
                    lineage=tuple(candidates),
                )
            )

        unique_hash_count += len(representatives)
        source_keys = tuple(
            sorted({key for record in component for key in record.source_record_keys})
        )
        identity = "\n".join([labels[0], *hashes, *source_keys])
        group_id = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]
        groups.append(
            SourceGroup(
                group_id=group_id,
                class_name=labels[0],
                images=tuple(representatives),
                source_record_keys=source_keys,
            )
        )

    groups.sort(key=lambda item: (item.class_name, item.group_id))
    return groups, errors, len(records) - unique_hash_count


def _target_counts(total: int, ratios: Mapping[str, float]) -> dict[str, int]:
    raw = {split: total * ratios[split] for split in SPLITS}
    counts = {split: int(raw[split]) for split in SPLITS}
    remaining = total - sum(counts.values())
    order = sorted(SPLITS, key=lambda split: (-(raw[split] - counts[split]), SPLITS.index(split)))
    for split in order[:remaining]:
        counts[split] += 1
    return counts


def _assign_class_groups(
    class_name: str,
    groups: Sequence[SourceGroup],
    policy: BuildPolicy,
) -> dict[str, str]:
    total = sum(len(group.images) for group in groups)
    targets = _target_counts(total, policy.split_ratios)
    counts = {split: 0 for split in SPLITS}
    group_counts = {split: 0 for split in SPLITS}

    def tie_key(group: SourceGroup) -> str:
        value = f"{policy.seed}:{class_name}:{group.group_id}"
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    ordered = sorted(groups, key=lambda group: (-len(group.images), tie_key(group)))
    assignments: dict[str, str] = {}
    for index, group in enumerate(ordered):
        remaining_group_count = len(ordered) - index
        empty_splits = [split for split in SPLITS if group_counts[split] == 0]
        choices = empty_splits if remaining_group_count == len(empty_splits) else list(SPLITS)

        def score(split: str) -> tuple[float, int]:
            projected = dict(counts)
            projected[split] += len(group.images)
            error = sum((projected[name] - targets[name]) ** 2 for name in SPLITS)
            return error, SPLITS.index(split)

        selected = min(choices, key=score)
        assignments[group.group_id] = selected
        counts[selected] += len(group.images)
        group_counts[selected] += 1
    return assignments


def create_build_plan(
    policy: BuildPolicy,
    manifest_paths: Sequence[Path] | None = None,
    project_root: Path = PROJECT_ROOT,
) -> BuildPlan:
    selected_manifests = tuple(manifest_paths or policy.input_manifests)
    records, errors, manifest_stats, manifest_digests = collect_approved_images(
        selected_manifests, policy, project_root
    )
    groups, grouping_errors, duplicate_rows_removed = build_source_groups(records)
    errors.extend(grouping_errors)

    groups_by_class: defaultdict[str, list[SourceGroup]] = defaultdict(list)
    for group in groups:
        groups_by_class[group.class_name].append(group)

    warnings: list[str] = []
    images: list[PlannedImage] = []
    for class_name in policy.class_order:
        class_groups = groups_by_class.get(class_name, [])
        unique_images = sum(len(group.images) for group in class_groups)
        if unique_images == 0:
            errors.append(f"{class_name}: missing approved, traceable images")
            continue
        if unique_images < policy.minimum_unique_images_per_class:
            errors.append(
                f"{class_name}: {unique_images} unique images; "
                f"minimum is {policy.minimum_unique_images_per_class}"
            )
        if len(class_groups) < policy.minimum_source_groups_per_class:
            errors.append(
                f"{class_name}: {len(class_groups)} independent source groups; "
                f"minimum is {policy.minimum_source_groups_per_class}"
            )

        assignments = _assign_class_groups(class_name, class_groups, policy)
        split_counts: Counter = Counter()
        for group in class_groups:
            split = assignments[group.group_id]
            for deduplicated_image in group.images:
                image = deduplicated_image.representative
                suffix = image.source_path.suffix.casefold()
                relative_path = Path(split) / class_name / f"{image.sha256}{suffix}"
                images.append(
                    PlannedImage(
                        image=image,
                        lineage=deduplicated_image.lineage,
                        split=split,
                        group_id=group.group_id,
                        source_record_keys=group.source_record_keys,
                        relative_path=relative_path,
                    )
                )
                split_counts[split] += 1

        if policy.require_every_class_in_every_split:
            missing_splits = [split for split in SPLITS if split_counts[split] == 0]
            if missing_splits:
                errors.append(
                    f"{class_name}: no images assigned to split(s) {', '.join(missing_splits)}"
                )

    unknown_classes = sorted(set(groups_by_class) - set(policy.class_order))
    if unknown_classes:
        errors.append(f"Approved rows contain non-canonical classes: {unknown_classes}")

    images.sort(key=lambda item: item.relative_path.as_posix())
    return BuildPlan(
        policy=policy,
        records=tuple(records),
        groups=tuple(groups),
        images=tuple(images),
        errors=tuple(errors),
        warnings=tuple(warnings),
        manifest_stats=manifest_stats,
        manifest_digests=manifest_digests,
        duplicate_rows_removed=duplicate_rows_removed,
    )


def _class_summary(plan: BuildPlan) -> dict[str, dict[str, int]]:
    summary: dict[str, dict[str, int]] = {}
    for class_name in plan.policy.class_order:
        split_counts = Counter(
            item.split for item in plan.images if item.image.class_name == class_name
        )
        groups = [group for group in plan.groups if group.class_name == class_name]
        summary[class_name] = {
            "unique_images": sum(split_counts.values()),
            "source_groups": len(groups),
            **{split: split_counts[split] for split in SPLITS},
        }
    return summary


def render_readiness(plan: BuildPlan, project_root: Path = PROJECT_ROOT) -> str:
    lines = [
        "29-class CNN staging readiness",
        "==============================",
        f"Status: {'READY' if plan.ready else 'NOT READY'}",
        f"Approved manifest rows accepted: {len(plan.records)}",
        f"Unique images after exact-hash deduplication: {len(plan.images)}",
        f"Duplicate approved rows removed: {plan.duplicate_rows_removed}",
        f"Independent source/hash groups: {len(plan.groups)}",
        "",
        "Per-class plan:",
    ]
    for class_name, values in _class_summary(plan).items():
        lines.append(
            f"- {class_name}: unique={values['unique_images']}, "
            f"groups={values['source_groups']}, train={values['train']}, "
            f"val={values['val']}, test={values['test']}"
        )
    if plan.errors:
        lines.extend(["", "Blocking errors:"])
        lines.extend(f"- {error}" for error in plan.errors)
    if plan.warnings:
        lines.extend(["", "Warnings:"])
        lines.extend(f"- {warning}" for warning in plan.warnings)
    lines.extend(
        [
            "",
            "Dry run only; no files were copied." if not plan.ready else "Readiness checks passed.",
        ]
    )
    return "\n".join(lines)


def _manifest_snapshot_paths(plan: BuildPlan) -> dict[str, Path]:
    snapshots: dict[str, Path] = {}
    for manifest_path, digest in sorted(plan.manifest_digests.items()):
        path_token = hashlib.sha256(manifest_path.encode("utf-8")).hexdigest()[:8]
        filename = f"{digest[:16]}-{path_token}-{Path(manifest_path).name}"
        snapshots[manifest_path] = Path("input_manifests") / filename
    return snapshots


def _write_dataset_manifest(
    plan: BuildPlan,
    target: Path,
    project_root: Path,
    manifest_snapshots: Mapping[str, Path],
) -> None:
    fields = (
        "staged_path",
        "split",
        "class_name",
        "sha256",
        "group_id",
        "source_record_keys",
        "entry_id",
        "approval_status",
        "source_file",
        "source_manifest",
        "source_manifest_sha256",
        "source_manifest_snapshot",
        "source_manifest_row",
        "source",
        "source_record_id",
        "source_record_url",
        "source_image_url",
        "rights_or_license",
        "reviewed_plant_part",
        "lineage_json",
    )
    with (target / "dataset_manifest.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for item in plan.images:
            image = item.image
            manifest_key = str(image.manifest_path.resolve())
            manifest_digest = plan.manifest_digests[manifest_key]
            snapshot_path = manifest_snapshots[manifest_key]
            lineage = []
            for source_row in item.lineage:
                lineage_manifest_key = str(source_row.manifest_path.resolve())
                lineage.append(
                    {
                        "entry_id": source_row.entry_id,
                        "approval_status": source_row.approval_status,
                        "source_file": _relative_or_absolute(
                            source_row.source_path, project_root
                        ),
                        "source_manifest": _relative_or_absolute(
                            source_row.manifest_path, project_root
                        ),
                        "source_manifest_sha256": plan.manifest_digests[
                            lineage_manifest_key
                        ],
                        "source_manifest_snapshot": manifest_snapshots[
                            lineage_manifest_key
                        ].as_posix(),
                        "source_manifest_row": source_row.manifest_row,
                    }
                )
            writer.writerow(
                {
                    "staged_path": item.relative_path.as_posix(),
                    "split": item.split,
                    "class_name": image.class_name,
                    "sha256": image.sha256,
                    "group_id": item.group_id,
                    "source_record_keys": json.dumps(item.source_record_keys),
                    "entry_id": image.entry_id,
                    "approval_status": image.approval_status,
                    "source_file": _relative_or_absolute(image.source_path, project_root),
                    "source_manifest": _relative_or_absolute(image.manifest_path, project_root),
                    "source_manifest_sha256": manifest_digest,
                    "source_manifest_snapshot": snapshot_path.as_posix(),
                    "source_manifest_row": image.manifest_row,
                    "source": image.source,
                    "source_record_id": image.source_record_id,
                    "source_record_url": image.source_record_url,
                    "source_image_url": image.source_image_url,
                    "rights_or_license": image.rights_or_license,
                    "reviewed_plant_part": image.reviewed_plant_part,
                    "lineage_json": json.dumps(lineage, separators=(",", ":")),
                }
            )


def _preflight_build(plan: BuildPlan) -> None:
    if not plan.manifest_digests:
        raise DatasetBuildError("No immutable input-manifest evidence is available for this plan.")
    for manifest_path, expected_hash in plan.manifest_digests.items():
        source = Path(manifest_path).resolve()
        if not source.is_file():
            raise DatasetBuildError(f"Input manifest disappeared after planning: {source}")
        actual_hash = _sha256(source)
        if actual_hash != expected_hash:
            raise DatasetBuildError(
                f"Input manifest changed after planning: {source} "
                f"(expected {expected_hash}, got {actual_hash})"
            )

    verified_sources: dict[Path, str] = {}

    def verify_lineage_source(lineage_row: ApprovedImage) -> None:
        source = lineage_row.source_path.resolve()
        if not _is_within(source, plan.policy.allowed_input_roots):
            raise DatasetBuildError(f"Source escaped the allowed candidate/raw roots: {source}")
        if lineage_row.approval_status != plan.policy.required_approval_status:
            raise DatasetBuildError(
                f"Lineage row is not explicitly approved: {lineage_row.entry_id}"
            )
        if not source.is_file():
            raise DatasetBuildError(f"Source image disappeared after planning: {source}")
        actual_hash = verified_sources.get(source)
        if actual_hash is None:
            actual_hash = _sha256(source)
            verified_sources[source] = actual_hash
        if actual_hash != lineage_row.sha256:
            raise DatasetBuildError(
                f"Source image changed after planning: {source} "
                f"(expected {lineage_row.sha256}, got {actual_hash})"
            )

    for item in plan.images:
        lineage_sources = {row.source_path.resolve() for row in item.lineage}
        if item.image.source_path.resolve() not in lineage_sources:
            raise DatasetBuildError(
                f"Representative image is missing from its approval lineage: {item.image.source_path}"
            )
        for lineage_row in item.lineage:
            lineage_manifest = str(lineage_row.manifest_path.resolve())
            if lineage_manifest not in plan.manifest_digests:
                raise DatasetBuildError(
                    f"Missing manifest digest for approved row: {lineage_row.manifest_path}"
                )
            verify_lineage_source(lineage_row)


def _validated_destinations(plan: BuildPlan, target: Path) -> list[tuple[PlannedImage, Path]]:
    if len(set(plan.policy.class_order)) != len(plan.policy.class_order):
        raise DatasetBuildError("Class order contains duplicate names.")
    for class_name in plan.policy.class_order:
        if not CLASS_COMPONENT_PATTERN.fullmatch(class_name):
            raise DatasetBuildError(
                f"Class name is not a safe single directory component: {class_name!r}"
            )

    destinations: list[tuple[PlannedImage, Path]] = []
    for item in plan.images:
        if item.split not in SPLITS:
            raise DatasetBuildError(f"Invalid split in build plan: {item.split!r}")
        if item.image.class_name not in plan.policy.class_order:
            raise DatasetBuildError(
                f"Planned image has an unconfigured class: {item.image.class_name!r}"
            )
        parts = item.relative_path.parts
        suffix = item.image.source_path.suffix.casefold()
        if suffix not in SUPPORTED_EXTENSIONS:
            raise DatasetBuildError(f"Planned source has an unsupported image extension: {suffix}")
        expected_filename = f"{item.image.sha256}{suffix}"
        if (
            item.relative_path.is_absolute()
            or len(parts) != 3
            or parts[0] != item.split
            or parts[1] != item.image.class_name
            or parts[2] != expected_filename
        ):
            raise DatasetBuildError(
                f"Unsafe or inconsistent staged relative path: {item.relative_path}"
            )
        destination = (target / item.relative_path).resolve()
        if target not in destination.parents:
            raise DatasetBuildError(f"Staged image path escapes the version directory: {destination}")
        destinations.append((item, destination))
    return destinations


def build_staging_dataset(
    plan: BuildPlan,
    version: str,
    config_payload: Mapping,
    project_root: Path = PROJECT_ROOT,
    staging_root: Path | None = None,
) -> Path:
    if not plan.ready:
        raise DatasetBuildError("Readiness checks failed; no staging dataset was written.")
    if not VERSION_PATTERN.fullmatch(version):
        raise DatasetBuildError(
            "Version must start with an alphanumeric character and contain only letters, "
            "numbers, dots, underscores, or hyphens."
        )

    root = (staging_root or plan.policy.staging_root).resolve()
    staging_boundary = (project_root.resolve() / "dataset" / "staging").resolve()
    if root != staging_boundary and staging_boundary not in root.parents:
        raise DatasetBuildError(
            f"Staging output must stay under {staging_boundary}; received {root}"
        )
    target = (root / version).resolve()
    if root not in target.parents:
        raise DatasetBuildError("Resolved version directory escapes the staging root.")
    if target.exists():
        raise DatasetBuildError(f"Versioned staging directory already exists: {target}")

    destinations = _validated_destinations(plan, target)
    _preflight_build(plan)

    target.mkdir(parents=True)
    incomplete_marker = target / "BUILD_INCOMPLETE"
    incomplete_marker.write_text(
        "This directory is incomplete unless BUILD_COMPLETE.json is present.\n",
        encoding="utf-8",
    )

    for split in SPLITS:
        for class_name in plan.policy.class_order:
            (target / split / class_name).mkdir(parents=True, exist_ok=True)

    for item, destination in destinations:
        shutil.copy2(item.image.source_path, destination)
        copied_hash = _sha256(destination)
        if copied_hash != item.image.sha256:
            raise DatasetBuildError(
                f"Copied image failed SHA-256 verification: {destination} "
                f"(expected {item.image.sha256}, got {copied_hash})"
            )

    manifest_snapshots = _manifest_snapshot_paths(plan)
    for manifest_path, relative_snapshot in manifest_snapshots.items():
        snapshot = target / relative_snapshot
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(manifest_path, snapshot)
        copied_hash = _sha256(snapshot)
        expected_hash = plan.manifest_digests[manifest_path]
        if copied_hash != expected_hash:
            raise DatasetBuildError(
                f"Copied manifest failed SHA-256 verification: {snapshot} "
                f"(expected {expected_hash}, got {copied_hash})"
            )

    (target / "class_order.json").write_text(
        json.dumps(list(plan.policy.class_order), indent=2) + "\n",
        encoding="utf-8",
    )
    input_manifest_evidence = [
        {
            "source": _relative_or_absolute(Path(path), project_root.resolve()),
            "sha256": plan.manifest_digests[path],
            "snapshot": manifest_snapshots[path].as_posix(),
        }
        for path in sorted(plan.manifest_digests)
    ]
    config_snapshot = dict(config_payload)
    config_snapshot["resolved_input_manifests"] = input_manifest_evidence
    (target / "config_snapshot.json").write_text(
        json.dumps(config_snapshot, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_dataset_manifest(
        plan,
        target,
        project_root.resolve(),
        manifest_snapshots,
    )

    report = {
        "schema_version": 1,
        "status": "complete",
        "version": version,
        "built_at": datetime.now(timezone.utc).isoformat(),
        "class_count": len(plan.policy.class_order),
        "class_order": list(plan.policy.class_order),
        "accepted_manifest_rows": len(plan.records),
        "unique_images": len(plan.images),
        "duplicate_rows_removed": plan.duplicate_rows_removed,
        "source_groups": len(plan.groups),
        "class_summary": _class_summary(plan),
        "input_manifests": input_manifest_evidence,
        "manifest_stats": plan.manifest_stats,
    }
    (target / "build_report.json").write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
    )
    artifact_paths = {
        "class_order.json": target / "class_order.json",
        "config_snapshot.json": target / "config_snapshot.json",
        "dataset_manifest.csv": target / "dataset_manifest.csv",
        "build_report.json": target / "build_report.json",
    }
    (target / "BUILD_COMPLETE.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "complete",
                "version": version,
                "unique_images": len(plan.images),
                "class_count": len(plan.policy.class_order),
                "class_order": list(plan.policy.class_order),
                "built_at": report["built_at"],
                "artifact_sha256": {
                    name: _sha256(path) for name, path in artifact_paths.items()
                },
                "input_manifests": input_manifest_evidence,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    incomplete_marker.unlink()
    return target


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Audit approved, traceable inputs and optionally build a versioned 29-class "
            "CNN staging dataset. The default is a read-only dry run."
        )
    )
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument(
        "--manifest",
        type=Path,
        action="append",
        help="Override configured input manifests; may be supplied more than once.",
    )
    parser.add_argument("--version", help="Required with --apply, for example 2026-09-24-v1.")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Copy approved files into a new versioned staging directory.",
    )
    args = parser.parse_args(argv)

    try:
        config_path = args.config.resolve()
        policy, config_payload = load_policy(config_path, PROJECT_ROOT)
        manifests = (
            tuple(_resolve_from_project(str(path), PROJECT_ROOT) for path in args.manifest)
            if args.manifest
            else None
        )
        plan = create_build_plan(policy, manifests, PROJECT_ROOT)
        print(render_readiness(plan, PROJECT_ROOT))
        if not plan.ready:
            return 2
        if not args.apply:
            print("Run again with --apply --version <version> to create the staging copy.")
            return 0
        if not args.version:
            raise DatasetBuildError("--version is required with --apply.")
        target = build_staging_dataset(
            plan,
            args.version,
            config_payload,
            PROJECT_ROOT,
        )
        print(f"Staging dataset created: {target}")
        return 0
    except (DatasetBuildError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
