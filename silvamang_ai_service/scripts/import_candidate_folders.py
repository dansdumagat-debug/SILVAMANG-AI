from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import sys
import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Mapping, Sequence


AI_SERVICE_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = AI_SERVICE_ROOT.parent
if str(AI_SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_SERVICE_ROOT))

from training.cnn_classifier.build_staged_29_dataset import (  # noqa: E402
    CANONICAL_CLASS_ORDER,
    BuildPlan,
    DatasetBuildError,
    create_build_plan,
    load_policy,
    render_readiness,
)

try:  # pragma: no cover - import shape differs between CLI and tests
    from .candidate_manifest_lock import (
        CandidateManifestBusyError,
        candidate_manifest_write_lock,
    )
except ImportError:  # pragma: no cover
    from candidate_manifest_lock import (
        CandidateManifestBusyError,
        candidate_manifest_write_lock,
    )


DEFAULT_CANDIDATE_ROOT = PROJECT_ROOT / "dataset" / "candidates"
DEFAULT_SOURCE_MANIFEST = PROJECT_ROOT / "dataset" / "metadata" / "candidate_image_manifest.csv"
DEFAULT_OUTPUT_MANIFEST = (
    PROJECT_ROOT / "dataset" / "metadata" / "cnn_29_folder_approved_manifest.csv"
)
DEFAULT_CONFIG_PATH = (
    AI_SERVICE_ROOT / "training" / "cnn_classifier" / "staged_29_class_config.json"
)
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
EXCLUDED_REVIEW_STATUSES = {"flagged", "rejected"}
INTERNAL_SOURCE = "SILVAMANG manually curated candidate folders"
INTERNAL_PERMISSION = (
    "User directed inclusion for local SILVAMANG model training; "
    "external reuse rights not asserted."
)

MANIFEST_FIELDS = (
    "candidate_id",
    "file_path",
    "scientific_name",
    "reviewed_plant_part",
    "source",
    "source_record_id",
    "source_group_id",
    "observation_id",
    "source_record_url",
    "source_image_url",
    "creator",
    "rights_holder",
    "license",
    "permission_status",
    "country",
    "state_province",
    "locality",
    "downloaded_at",
    "sha256",
    "review_status",
    "review_notes",
    "metadata_origin_manifest",
    "metadata_origin_row",
)

PART_ALIASES = {
    "bark": "bark",
    "barks": "bark",
    "leaf": "leaves",
    "leaves": "leaves",
    "root": "roots",
    "roots": "roots",
    "flower": "flowers",
    "flowers": "flowers",
    "canopy": "canopy",
    "unknown": "unclassified",
    "unclassified": "unclassified",
}


@dataclass(frozen=True)
class FolderImage:
    path: Path
    relative_path: str
    class_name: str
    plant_part: str
    sha256: str


@dataclass(frozen=True)
class FolderImportPlan:
    rows: tuple[dict[str, str], ...]
    scanned_files: int
    unique_hashes: int
    metadata_matched_files: int
    internal_metadata_files: int
    excluded_review_files: int
    duplicate_files: int
    cross_label_hashes: Mapping[str, tuple[FolderImage, ...]]
    invalid_files: tuple[str, ...]
    read_errors: tuple[str, ...]


def normalize_part(value: str, class_name: str) -> str:
    normalized = "_".join(re.findall(r"[a-z0-9]+", value.casefold()))
    part = PART_ALIASES.get(normalized, "")
    if class_name == "unknown":
        return "unclassified" if part == "unclassified" else ""
    return part if part != "unclassified" else ""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _slug(value: str) -> str:
    ascii_value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return "-".join(re.findall(r"[a-z0-9]+", ascii_value.casefold()))


def infer_source_group_id(class_name: str, filename: str, digest: str) -> str:
    """Infer a stable, deliberately broad group from a local filename.

    The group is namespaced by class because these local files have no external
    observation identifier. Known collector filenames retain their record ID;
    dated camera images share a capture-minute group; parenthesized local
    sequences use blocks of ten so likely neighboring views remain in one split.
    """

    stem = Path(filename).stem.casefold()
    for prefix in ("gbif", "inat", "commons"):
        match = re.match(rf"^{prefix}[_ -]+([0-9]+)(?:[_ -]|$)", stem)
        if match:
            return f"manual-folder:{class_name}:{prefix}-{match.group(1)}"

    date_match = re.search(
        r"(20[0-9]{2})[-_]?([01][0-9])[-_]?([0-3][0-9])"
        r"(?:[t _-]?([0-2][0-9])[:_-]?([0-5][0-9]))?",
        stem,
    )
    if date_match:
        date_parts = date_match.groups()
        capture_day = "".join(date_parts[:3])
        if date_parts[3] and date_parts[4]:
            return (
                f"manual-folder:{class_name}:capture-minute-"
                f"{capture_day}-{date_parts[3]}{date_parts[4]}"
            )
        return f"manual-folder:{class_name}:capture-day-{capture_day}"

    sequence_stem = re.sub(r"(?:[_ -]+copy(?:[_ -]*[0-9]+)?)$", "", stem).strip()
    sequence_match = re.match(r"^(.*?)\s*\(([0-9]+)\)$", sequence_stem)
    if sequence_match:
        series_name = _slug(sequence_match.group(1)) or "numbered-files"
        sequence_number = max(1, int(sequence_match.group(2)))
        block_start = ((sequence_number - 1) // 10) * 10 + 1
        block_end = block_start + 9
        return (
            f"manual-folder:{class_name}:series-{series_name}-"
            f"{block_start:04d}-{block_end:04d}"
        )

    base = stem
    base = re.sub(r"[_ -][0-9a-f]{10,64}$", "", base)
    base = re.sub(r"\s*\([0-9]+\)$", "", base)
    base = re.sub(r"(?:[_ -](?:copy)?[0-9]+)+$", "", base)
    base = re.sub(r"(?:[_ -](?:small|medium|large|original|thumb|thumbnail))+$", "", base)
    group_hint = _slug(base)[:96]
    if not group_hint:
        group_hint = f"file-{digest[:16]}"
    return f"manual-folder:{class_name}:{group_hint}"


def _relative_to_project(path: Path, project_root: Path) -> str:
    return path.resolve().relative_to(project_root.resolve()).as_posix()


def _scan_candidate_folders(
    candidate_root: Path,
    project_root: Path,
    class_order: Sequence[str],
) -> tuple[list[FolderImage], list[str], list[str], int]:
    candidate_root = candidate_root.resolve()
    project_root = project_root.resolve()
    if not candidate_root.is_dir():
        raise ValueError(f"Candidate root does not exist: {candidate_root}")
    try:
        candidate_root.relative_to(project_root)
    except ValueError as exc:
        raise ValueError(
            f"Candidate root must stay inside the project root: {candidate_root}"
        ) from exc

    images: list[FolderImage] = []
    invalid_files: list[str] = []
    read_errors: list[str] = []
    scanned_files = 0

    for class_name in class_order:
        class_root = candidate_root / class_name
        if not class_root.is_dir():
            continue
        for path in sorted(class_root.rglob("*"), key=lambda item: item.as_posix().casefold()):
            if not path.is_file() or path.suffix.casefold() not in SUPPORTED_EXTENSIONS:
                continue
            scanned_files += 1
            if path.is_symlink():
                invalid_files.append(f"symlink skipped: {path}")
                continue
            resolved = path.resolve()
            try:
                relative_to_class = resolved.relative_to(class_root.resolve())
                resolved.relative_to(candidate_root)
            except ValueError:
                invalid_files.append(f"path escaped candidate root: {path}")
                continue
            if len(relative_to_class.parts) < 2:
                invalid_files.append(f"missing plant-part folder: {path}")
                continue
            plant_part = normalize_part(relative_to_class.parts[0], class_name)
            if not plant_part:
                invalid_files.append(
                    f"unsupported plant-part folder {relative_to_class.parts[0]!r}: {path}"
                )
                continue
            try:
                digest = sha256_file(resolved)
            except OSError as exc:
                read_errors.append(f"{path}: {exc}")
                continue
            images.append(
                FolderImage(
                    path=resolved,
                    relative_path=_relative_to_project(resolved, project_root),
                    class_name=class_name,
                    plant_part=plant_part,
                    sha256=digest,
                )
            )
    return images, invalid_files, read_errors, scanned_files


def _read_metadata_by_hash(manifest_path: Path) -> dict[str, list[dict[str, str]]]:
    by_hash: defaultdict[str, list[dict[str, str]]] = defaultdict(list)
    if not manifest_path.is_file():
        return {}
    with manifest_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row_number, raw_row in enumerate(reader, start=2):
            row = {str(key): str(value or "").strip() for key, value in raw_row.items() if key}
            digest = row.get("sha256", "").casefold()
            if not SHA256_PATTERN.fullmatch(digest):
                continue
            row["metadata_origin_manifest"] = str(manifest_path.resolve())
            row["metadata_origin_row"] = str(row_number)
            by_hash[digest].append(row)
    return dict(by_hash)


def _metadata_priority(row: Mapping[str, str]) -> tuple[int, int, str]:
    status = str(row.get("review_status") or "").strip().casefold()
    status_rank = {"rejected": 0, "flagged": 1, "approved": 2, "pending": 3}.get(status, 4)
    populated = sum(bool(str(row.get(field) or "").strip()) for field in MANIFEST_FIELDS)
    return status_rank, -populated, str(row.get("candidate_id") or "")


def _folder_review_note(previous_status: str, previous_note: str) -> str:
    note = "Species and plant part approved from the manually curated folder placement."
    if previous_status:
        note += f" Previous review status: {previous_status}."
    if previous_note:
        note += f" Previous note: {previous_note}"
    return note


def _row_for_image(
    image: FolderImage,
    metadata_rows: Sequence[Mapping[str, str]],
) -> tuple[dict[str, str], bool, bool]:
    excluded_rows = [
        row
        for row in metadata_rows
        if str(row.get("review_status") or "").strip().casefold()
        in EXCLUDED_REVIEW_STATUSES
    ]
    metadata = (
        min(excluded_rows or list(metadata_rows), key=_metadata_priority)
        if metadata_rows
        else None
    )
    row = {field: "" for field in MANIFEST_FIELDS}

    if metadata is not None:
        for field in MANIFEST_FIELDS:
            row[field] = str(metadata.get(field) or "").strip()
        previous_status = str(metadata.get("review_status") or "").strip().casefold()
        previous_note = str(metadata.get("review_notes") or "").strip()
        if excluded_rows:
            row["review_status"] = previous_status
            row["review_notes"] = previous_note
        else:
            row["review_status"] = "approved"
            row["review_notes"] = _folder_review_note(previous_status, previous_note)
    else:
        path_token = hashlib.sha256(image.relative_path.encode("utf-8")).hexdigest()[:10]
        row.update(
            {
                "candidate_id": f"folder_{image.sha256[:16]}_{path_token}",
                "source": INTERNAL_SOURCE,
                "source_group_id": infer_source_group_id(
                    image.class_name, image.path.name, image.sha256
                ),
                "permission_status": INTERNAL_PERMISSION,
                "review_status": "approved",
                "review_notes": (
                    "Species and plant part approved from the manually curated folder placement. "
                    "Source grouping was inferred conservatively from the filename."
                ),
            }
        )

    row["file_path"] = image.relative_path
    row["scientific_name"] = image.class_name
    row["reviewed_plant_part"] = image.plant_part
    row["sha256"] = image.sha256
    if not row["candidate_id"]:
        path_token = hashlib.sha256(image.relative_path.encode("utf-8")).hexdigest()[:10]
        row["candidate_id"] = f"folder_{image.sha256[:16]}_{path_token}"
    if row["review_status"] == "approved":
        if not row["source"]:
            row["source"] = INTERNAL_SOURCE
        if not any(
            row[field] for field in ("source_record_id", "source_group_id", "observation_id")
        ):
            row["source_group_id"] = infer_source_group_id(
                image.class_name, image.path.name, image.sha256
            )
        if not row["license"] and not row["permission_status"]:
            row["permission_status"] = INTERNAL_PERMISSION
    return row, metadata is not None, bool(excluded_rows)


def create_import_plan(
    candidate_root: Path,
    source_manifest: Path,
    project_root: Path = PROJECT_ROOT,
    class_order: Sequence[str] = CANONICAL_CLASS_ORDER,
) -> FolderImportPlan:
    images, invalid_files, read_errors, scanned_files = _scan_candidate_folders(
        candidate_root, project_root, class_order
    )
    by_hash: defaultdict[str, list[FolderImage]] = defaultdict(list)
    for image in images:
        by_hash[image.sha256].append(image)

    cross_label_hashes = {
        digest: tuple(group)
        for digest, group in by_hash.items()
        if len({image.class_name for image in group}) > 1
    }
    metadata_by_hash = _read_metadata_by_hash(source_manifest.resolve())

    rows: list[dict[str, str]] = []
    metadata_matched_files = 0
    internal_metadata_files = 0
    excluded_review_files = 0
    for image in images:
        if image.sha256 in cross_label_hashes:
            continue
        row, matched, excluded = _row_for_image(
            image, metadata_by_hash.get(image.sha256, ())
        )
        rows.append(row)
        metadata_matched_files += int(matched)
        internal_metadata_files += int(not matched)
        excluded_review_files += int(excluded)

    rows.sort(
        key=lambda row: (
            row["scientific_name"],
            row["reviewed_plant_part"],
            row["sha256"],
            row["file_path"],
        )
    )
    return FolderImportPlan(
        rows=tuple(rows),
        scanned_files=scanned_files,
        unique_hashes=len(by_hash),
        metadata_matched_files=metadata_matched_files,
        internal_metadata_files=internal_metadata_files,
        excluded_review_files=excluded_review_files,
        duplicate_files=sum(
            len(group) - 1
            for group in by_hash.values()
            if len({image.class_name for image in group}) == 1
        ),
        cross_label_hashes=cross_label_hashes,
        invalid_files=tuple(invalid_files),
        read_errors=tuple(read_errors),
    )


def write_manifest_atomic(path: Path, rows: Sequence[Mapping[str, str]]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    with candidate_manifest_write_lock(path):
        with NamedTemporaryFile(
            "w",
            encoding="utf-8",
            newline="",
            dir=path.parent,
            prefix=f".{path.stem}_",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            writer = csv.DictWriter(
                temporary, fieldnames=MANIFEST_FIELDS, extrasaction="ignore"
            )
            writer.writeheader()
            writer.writerows(rows)
            temporary_path = Path(temporary.name)
        try:
            os.replace(temporary_path, path)
        finally:
            temporary_path.unlink(missing_ok=True)


def validate_import_plan(
    import_plan: FolderImportPlan,
    config_path: Path,
    project_root: Path,
    manifest_path: Path | None = None,
) -> BuildPlan:
    policy, _ = load_policy(config_path.resolve(), project_root.resolve())
    if manifest_path is not None:
        return create_build_plan(policy, (manifest_path.resolve(),), project_root.resolve())

    temporary_path: Path | None = None
    try:
        with NamedTemporaryFile(
            "w", encoding="utf-8", newline="", suffix=".csv", delete=False
        ) as temporary:
            writer = csv.DictWriter(
                temporary, fieldnames=MANIFEST_FIELDS, extrasaction="ignore"
            )
            writer.writeheader()
            writer.writerows(import_plan.rows)
            temporary_path = Path(temporary.name)
        return create_build_plan(policy, (temporary_path,), project_root.resolve())
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def render_import_report(
    plan: FolderImportPlan,
    output_manifest: Path,
    apply_changes: bool,
) -> str:
    lines = [
        "Candidate folder manifest import",
        "================================",
        f"Mode: {'apply' if apply_changes else 'dry run'}",
        f"Image files scanned: {plan.scanned_files}",
        f"Unique SHA-256 hashes: {plan.unique_hashes}",
        f"Same-species duplicate files retained for builder deduplication: {plan.duplicate_files}",
        f"Files using preserved manifest metadata: {plan.metadata_matched_files}",
        f"Files using internal manual-folder metadata: {plan.internal_metadata_files}",
        f"Files retained as flagged/rejected and excluded: {plan.excluded_review_files}",
        f"Cross-species hashes excluded: {len(plan.cross_label_hashes)}",
        f"Invalid-layout/part files excluded: {len(plan.invalid_files)}",
        f"Unreadable files excluded: {len(plan.read_errors)}",
        (
            f"Manifest written atomically: {output_manifest.resolve()}"
            if apply_changes
            else f"Manifest would be written to: {output_manifest.resolve()}"
        ),
    ]
    if plan.cross_label_hashes:
        lines.append("")
        lines.append("Cross-species exact duplicates:")
        for digest, images in sorted(plan.cross_label_hashes.items()):
            labels = sorted({image.class_name for image in images})
            paths = ", ".join(image.relative_path for image in images[:4])
            lines.append(f"- {digest}: classes={labels}; files={paths}")
    if plan.invalid_files:
        lines.extend(("", "Excluded layout/part examples:"))
        lines.extend(f"- {item}" for item in plan.invalid_files[:10])
    if plan.read_errors:
        lines.extend(("", "Read errors:"))
        lines.extend(f"- {item}" for item in plan.read_errors[:10])
    return "\n".join(lines)


def _path_from_project(value: Path | None, project_root: Path, default: Path) -> Path:
    if value is None:
        return default.resolve()
    return (value if value.is_absolute() else project_root / value).resolve()


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create a staging-compatible manifest from manually sorted candidate folders. "
            "The default is a read-only dry run."
        )
    )
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT)
    parser.add_argument("--candidate-root", type=Path)
    parser.add_argument("--source-manifest", type=Path)
    parser.add_argument("--output-manifest", type=Path)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Atomically write the curated manifest. Images and source manifests are untouched.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    project_root = args.project_root.resolve()
    candidate_root = _path_from_project(
        args.candidate_root,
        project_root,
        project_root / "dataset" / "candidates",
    )
    source_manifest = _path_from_project(
        args.source_manifest,
        project_root,
        project_root / "dataset" / "metadata" / "candidate_image_manifest.csv",
    )
    output_manifest = _path_from_project(
        args.output_manifest,
        project_root,
        project_root / "dataset" / "metadata" / "cnn_29_folder_approved_manifest.csv",
    )
    config_path = args.config.resolve()

    try:
        if output_manifest == source_manifest:
            raise ValueError("Output manifest must not overwrite the source candidate manifest.")
        import_plan = create_import_plan(
            candidate_root,
            source_manifest,
            project_root,
            CANONICAL_CLASS_ORDER,
        )
        build_plan = validate_import_plan(import_plan, config_path, project_root)
        if args.apply:
            write_manifest_atomic(output_manifest, import_plan.rows)
        print(render_import_report(import_plan, output_manifest, args.apply))
        print()
        print(render_readiness(build_plan, project_root))
        return 0
    except (
        CandidateManifestBusyError,
        DatasetBuildError,
        OSError,
        ValueError,
        csv.Error,
    ) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
