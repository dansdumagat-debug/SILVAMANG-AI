from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CANDIDATE_ROOT = PROJECT_ROOT / "dataset" / "candidates"
DEFAULT_MANIFEST_PATH = PROJECT_ROOT / "dataset" / "metadata" / "candidate_image_manifest.csv"
DEFAULT_STAGED_CONFIG_PATH = (
    PROJECT_ROOT
    / "silvamang_ai_service"
    / "training"
    / "cnn_classifier"
    / "staged_29_class_config.json"
)
DEFAULT_REFERENCE_ROOTS = (
    PROJECT_ROOT / "dataset" / "raw",
    PROJECT_ROOT / "dataset" / "processed" / "cnn_classification",
)

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
REQUIRED_MANIFEST_COLUMNS = {
    "candidate_id",
    "file_path",
    "scientific_name",
    "source_record_url",
    "creator",
    "rights_holder",
    "license",
    "sha256",
    "review_status",
}
APPROVED_STATUS = "approved"
ACTIONABLE_STATUSES = {"approved", "pending", "flagged"}
HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
EXAMPLE_LIMIT = 10


def image_files(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file()
        and not path.is_symlink()
        and path.suffix.casefold() in SUPPORTED_EXTENSIONS
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalized_label(value: str) -> str:
    return "_".join(re.findall(r"[a-z0-9]+", value.casefold()))


def normalized_part(value: str) -> str:
    aliases = {"barks": "bark", "leaf": "leaves", "flower": "flowers", "root": "roots"}
    part = normalized_label(value)
    return aliases.get(part, part or "unclassified")


def license_is_allowed(value: str) -> bool:
    license_value = value.strip().casefold().replace("http://", "https://")
    allowed_fragments = (
        "creativecommons.org/publicdomain/zero/",
        "creativecommons.org/publicdomain/mark/",
        "creativecommons.org/licenses/by/",
        "creativecommons.org/licenses/by-sa/",
        "cc0",
        "public domain",
        "cc by ",
        "cc-by-",
        "cc_by_",
    )
    blocked_fragments = (
        "by-nc",
        "by-nd",
        "by_nc",
        "by_nd",
        "noncommercial",
        "no derivatives",
    )
    return any(fragment in license_value for fragment in allowed_fragments) and not any(
        fragment in license_value for fragment in blocked_fragments
    )


def configured_minimum_approved_unique_images(config_path: Path) -> int:
    """Read the candidate readiness minimum from the staged dataset policy."""

    payload = json.loads(config_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Staged dataset config must be a JSON object: {config_path}")
    readiness = payload.get("readiness")
    if not isinstance(readiness, dict):
        raise ValueError(f"Staged dataset config has no readiness object: {config_path}")
    minimum = readiness.get("minimum_unique_images_per_class")
    if isinstance(minimum, bool) or not isinstance(minimum, int) or minimum < 1:
        raise ValueError(
            "Staged dataset readiness.minimum_unique_images_per_class "
            f"must be a positive integer: {config_path}"
        )
    return minimum


def _relative_display(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path)


def _candidate_identity(path: Path, candidate_root: Path) -> tuple[str, str]:
    relative_parts = path.relative_to(candidate_root).parts
    species = relative_parts[0] if relative_parts else "(root)"
    part = normalized_part(relative_parts[1]) if len(relative_parts) > 2 else "unclassified"
    return species, part


def _read_manifest(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    if not path.is_file():
        return [], sorted(REQUIRED_MANIFEST_COLUMNS)

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = set(reader.fieldnames or [])
        missing_columns = sorted(REQUIRED_MANIFEST_COLUMNS - fieldnames)
        rows = [
            {key: str(value or "").strip() for key, value in row.items() if key is not None}
            for row in reader
        ]
    return rows, missing_columns


def _manifest_path(
    value: str,
    *,
    project_root: Path,
    candidate_root: Path,
) -> tuple[Path | None, bool]:
    if not value:
        return None, False
    raw_path = Path(value)
    resolved = (raw_path if raw_path.is_absolute() else project_root / raw_path).resolve()
    try:
        resolved.relative_to(candidate_root.resolve())
    except ValueError:
        return None, False
    return resolved, True


def _hash_paths(paths: Iterable[Path]) -> tuple[dict[Path, str], list[dict[str, str]]]:
    hashes: dict[Path, str] = {}
    errors: list[dict[str, str]] = []
    for path in paths:
        try:
            hashes[path.resolve()] = sha256_file(path)
        except OSError as error:
            errors.append({"file": str(path), "error": str(error)})
    return hashes, errors


def _add_blocker(blockers: list[dict[str, Any]], code: str, count: int, message: str) -> None:
    if count:
        blockers.append({"code": code, "count": count, "message": message})


def audit_candidate_dataset(
    candidate_root: Path,
    manifest_path: Path,
    *,
    project_root: Path | None = None,
    reference_roots: Iterable[Path] = (),
    minimum_approved_unique_images_per_class: int | None = None,
    staged_config_path: Path = DEFAULT_STAGED_CONFIG_PATH,
) -> dict[str, Any]:
    """Audit candidate images without modifying the dataset or its manifest."""

    candidate_root = candidate_root.resolve()
    manifest_path = manifest_path.resolve()
    project_root = (project_root or PROJECT_ROOT).resolve()
    reference_roots = tuple(Path(root).resolve() for root in reference_roots)
    if minimum_approved_unique_images_per_class is None:
        minimum_approved_unique_images_per_class = (
            configured_minimum_approved_unique_images(staged_config_path.resolve())
        )
    if minimum_approved_unique_images_per_class < 0:
        raise ValueError("Minimum approved unique images per class cannot be negative.")

    files = image_files(candidate_root)
    file_hashes, read_errors = _hash_paths(files)
    hash_to_files: dict[str, list[Path]] = defaultdict(list)
    per_class_state: dict[str, dict[str, Any]] = {}

    for path, digest in file_hashes.items():
        hash_to_files[digest].append(path)
        species, part = _candidate_identity(path, candidate_root)
        state = per_class_state.setdefault(
            species,
            {
                "image_files": 0,
                "hashes": set(),
                "manifest_matched_files": 0,
                "untracked_files": 0,
                "approved_files": 0,
                "approved_hashes": set(),
                "status_file_counts": Counter(),
                "part_counts": Counter(),
            },
        )
        state["image_files"] += 1
        state["hashes"].add(digest)
        state["part_counts"][part] += 1

    manifest_rows, missing_columns = _read_manifest(manifest_path)
    manifest_hash_rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    manifest_status_counts: Counter[str] = Counter()
    invalid_hash_rows = 0
    invalid_path_rows = 0
    direct_paths_resolving = 0
    stale_actionable_paths = 0
    manifest_hash_mismatches = 0

    for row in manifest_rows:
        status = (row.get("review_status") or "pending").casefold()
        manifest_status_counts[status] += 1
        digest = row.get("sha256", "").casefold()
        if not HASH_PATTERN.fullmatch(digest):
            invalid_hash_rows += 1
        else:
            manifest_hash_rows[digest].append(row)

        resolved_path, valid_path = _manifest_path(
            row.get("file_path", ""),
            project_root=project_root,
            candidate_root=candidate_root,
        )
        if not valid_path:
            invalid_path_rows += 1
            if status in ACTIONABLE_STATUSES:
                stale_actionable_paths += 1
            continue
        if resolved_path is not None and resolved_path.is_file():
            direct_paths_resolving += 1
            actual_hash = file_hashes.get(resolved_path)
            if actual_hash is not None and HASH_PATTERN.fullmatch(digest) and actual_hash != digest:
                manifest_hash_mismatches += 1
        elif status in ACTIONABLE_STATUSES:
            stale_actionable_paths += 1

    untracked_files: list[Path] = []
    nonapproved_files: list[Path] = []
    metadata_issue_files: list[Path] = []
    folder_manifest_label_conflicts: list[dict[str, Any]] = []
    physical_files_matched = 0

    for path, digest in file_hashes.items():
        species, _ = _candidate_identity(path, candidate_root)
        state = per_class_state[species]
        rows = manifest_hash_rows.get(digest, [])
        if not rows:
            untracked_files.append(path)
            state["untracked_files"] += 1
            continue

        physical_files_matched += 1
        state["manifest_matched_files"] += 1
        statuses = {(row.get("review_status") or "pending").casefold() for row in rows}
        status_label = next(iter(statuses)) if len(statuses) == 1 else "ambiguous"
        state["status_file_counts"][status_label] += 1
        if statuses == {APPROVED_STATUS}:
            state["approved_files"] += 1
            state["approved_hashes"].add(digest)
        else:
            nonapproved_files.append(path)

        has_metadata_issue = any(
            not row.get("source_record_url")
            or not row.get("license")
            or not license_is_allowed(row.get("license", ""))
            or not (row.get("creator") or row.get("rights_holder"))
            for row in rows
        )
        if has_metadata_issue:
            metadata_issue_files.append(path)

        manifest_labels = {
            normalized_label(row.get("scientific_name", ""))
            for row in rows
            if row.get("scientific_name")
        }
        folder_label = normalized_label(species)
        if not manifest_labels or folder_label not in manifest_labels:
            folder_manifest_label_conflicts.append(
                {
                    "sha256": digest,
                    "file": _relative_display(path, candidate_root),
                    "folder_species": species,
                    "manifest_species": sorted(
                        {row.get("scientific_name", "") for row in rows if row.get("scientific_name")}
                    ),
                }
            )

    duplicate_groups = {
        digest: paths for digest, paths in hash_to_files.items() if len(paths) > 1
    }
    cross_label_groups: dict[str, list[Path]] = {}
    cross_part_groups: dict[str, list[Path]] = {}
    duplicate_examples: list[dict[str, Any]] = []

    for digest, paths in duplicate_groups.items():
        identities = [_candidate_identity(path, candidate_root) for path in paths]
        species = sorted({identity[0] for identity in identities})
        parts = sorted({identity[1] for identity in identities})
        if len(species) > 1:
            cross_label_groups[digest] = paths
        if len(parts) > 1:
            cross_part_groups[digest] = paths
        if len(duplicate_examples) < EXAMPLE_LIMIT:
            duplicate_examples.append(
                {
                    "sha256": digest,
                    "file_count": len(paths),
                    "species": species,
                    "parts": parts,
                    "files": [_relative_display(path, candidate_root) for path in paths],
                }
            )

    actionable_manifest_rows = [
        row
        for row in manifest_rows
        if (row.get("review_status") or "pending").casefold() in ACTIONABLE_STATUSES
    ]
    actionable_rows_without_physical_hash = sum(
        1
        for row in actionable_manifest_rows
        if row.get("sha256", "").casefold() not in hash_to_files
    )
    approved_rows_without_physical_hash = sum(
        1
        for row in manifest_rows
        if (row.get("review_status") or "pending").casefold() == APPROVED_STATUS
        and row.get("sha256", "").casefold() not in hash_to_files
    )

    repeated_source_groups = Counter(
        row.get("source_record_id", "")
        for row in manifest_rows
        if row.get("source_record_id")
    )
    repeated_source_groups = Counter(
        {key: count for key, count in repeated_source_groups.items() if count > 1}
    )

    reference_summaries: list[dict[str, Any]] = []
    reference_overlap_hashes: set[str] = set()
    reference_read_errors: list[dict[str, str]] = []
    for reference_root in reference_roots:
        reference_files = image_files(reference_root)
        reference_hashes_by_path, errors = _hash_paths(reference_files)
        reference_read_errors.extend(errors)
        candidate_matches = {
            digest for digest in reference_hashes_by_path.values() if digest in hash_to_files
        }
        reference_overlap_hashes.update(candidate_matches)
        reference_summaries.append(
            {
                "root": str(reference_root),
                "image_files": len(reference_files),
                "overlapping_unique_hashes": len(candidate_matches),
                "overlapping_candidate_files": sum(
                    len(hash_to_files[digest]) for digest in candidate_matches
                ),
            }
        )

    per_class: dict[str, dict[str, Any]] = {}
    low_count_classes: list[str] = []
    for species in sorted(per_class_state, key=str.casefold):
        state = per_class_state[species]
        approved_unique = len(state["approved_hashes"])
        if approved_unique < minimum_approved_unique_images_per_class:
            low_count_classes.append(species)
        per_class[species] = {
            "image_files": state["image_files"],
            "unique_hashes": len(state["hashes"]),
            "manifest_matched_files": state["manifest_matched_files"],
            "untracked_files": state["untracked_files"],
            "approved_files": state["approved_files"],
            "approved_unique_hashes": approved_unique,
            "status_file_counts": dict(sorted(state["status_file_counts"].items())),
            "part_counts": dict(sorted(state["part_counts"].items())),
        }

    blockers: list[dict[str, Any]] = []
    _add_blocker(blockers, "no_images", int(not files), "No candidate images were found.")
    _add_blocker(
        blockers,
        "manifest_missing",
        int(not manifest_path.is_file()),
        "The candidate manifest is missing.",
    )
    _add_blocker(
        blockers,
        "manifest_columns_missing",
        len(missing_columns),
        "Required candidate manifest columns are missing.",
    )
    _add_blocker(blockers, "image_read_errors", len(read_errors), "Some candidate files could not be hashed.")
    _add_blocker(
        blockers,
        "reference_read_errors",
        len(reference_read_errors),
        "Some reference files could not be hashed, so overlap checks are incomplete.",
    )
    _add_blocker(blockers, "invalid_manifest_hashes", invalid_hash_rows, "Manifest rows have invalid SHA-256 values.")
    _add_blocker(blockers, "invalid_manifest_paths", invalid_path_rows, "Manifest paths are empty or outside the candidate root.")
    _add_blocker(
        blockers,
        "stale_actionable_manifest_paths",
        stale_actionable_paths,
        "Pending, flagged, or approved manifest paths do not resolve to files.",
    )
    _add_blocker(
        blockers,
        "manifest_hash_mismatches",
        manifest_hash_mismatches,
        "Files at recorded manifest paths do not match their recorded hashes.",
    )
    _add_blocker(blockers, "untracked_images", len(untracked_files), "Images have no matching manifest hash.")
    _add_blocker(
        blockers,
        "nonapproved_images",
        len(nonapproved_files),
        "Manifest-matched images are not consistently approved.",
    )
    _add_blocker(
        blockers,
        "metadata_issues",
        len(metadata_issue_files),
        "Tracked images have missing attribution/source fields or unsupported licenses.",
    )
    _add_blocker(
        blockers,
        "folder_manifest_label_conflicts",
        len(folder_manifest_label_conflicts),
        "Folder species labels conflict with manifest species labels.",
    )
    _add_blocker(blockers, "exact_duplicate_groups", len(duplicate_groups), "Exact duplicate candidate images remain.")
    _add_blocker(
        blockers,
        "cross_label_duplicate_groups",
        len(cross_label_groups),
        "Identical images appear under different species labels.",
    )
    _add_blocker(
        blockers,
        "approved_rows_missing_images",
        approved_rows_without_physical_hash,
        "Approved manifest rows do not have a matching physical image.",
    )
    _add_blocker(
        blockers,
        "reference_overlap",
        len(reference_overlap_hashes),
        "Candidate images already exist in a reference dataset.",
    )
    _add_blocker(
        blockers,
        "classes_below_minimum",
        len(low_count_classes),
        (
            "Classes have fewer than "
            f"{minimum_approved_unique_images_per_class} approved unique images."
        ),
    )

    return {
        "schema_version": 1,
        "ready": not blockers,
        "candidate_root": str(candidate_root),
        "manifest_path": str(manifest_path),
        "minimum_approved_unique_images_per_class": minimum_approved_unique_images_per_class,
        "summary": {
            "classes": len(per_class),
            "image_files": len(files),
            "successfully_hashed_files": len(file_hashes),
            "unique_hashes": len(hash_to_files),
            "duplicate_groups": len(duplicate_groups),
            "files_in_duplicate_groups": sum(len(paths) for paths in duplicate_groups.values()),
            "cross_label_duplicate_groups": len(cross_label_groups),
            "cross_part_duplicate_groups": len(cross_part_groups),
        },
        "manifest": {
            "exists": manifest_path.is_file(),
            "rows": len(manifest_rows),
            "missing_columns": missing_columns,
            "status_counts": dict(sorted(manifest_status_counts.items())),
            "direct_paths_resolving": direct_paths_resolving,
            "stale_actionable_paths": stale_actionable_paths,
            "invalid_path_rows": invalid_path_rows,
            "invalid_hash_rows": invalid_hash_rows,
            "hash_mismatches": manifest_hash_mismatches,
            "physical_files_matched_by_hash": physical_files_matched,
            "untracked_physical_files": len(untracked_files),
            "actionable_rows_without_physical_hash": actionable_rows_without_physical_hash,
            "approved_rows_without_physical_hash": approved_rows_without_physical_hash,
            "repeated_source_groups": len(repeated_source_groups),
            "rows_in_repeated_source_groups": sum(repeated_source_groups.values()),
        },
        "per_class": per_class,
        "reference_overlap": {
            "unique_candidate_hashes": len(reference_overlap_hashes),
            "candidate_files": sum(
                len(hash_to_files[digest]) for digest in reference_overlap_hashes
            ),
            "roots": reference_summaries,
        },
        "examples": {
            "untracked_files": [
                _relative_display(path, candidate_root) for path in untracked_files[:EXAMPLE_LIMIT]
            ],
            "duplicate_groups": duplicate_examples,
            "cross_label_duplicate_groups": [
                {
                    "sha256": digest,
                    "files": [_relative_display(path, candidate_root) for path in paths],
                }
                for digest, paths in list(cross_label_groups.items())[:EXAMPLE_LIMIT]
            ],
            "folder_manifest_label_conflicts": folder_manifest_label_conflicts[:EXAMPLE_LIMIT],
            "image_read_errors": read_errors[:EXAMPLE_LIMIT],
            "reference_read_errors": reference_read_errors[:EXAMPLE_LIMIT],
        },
        "low_count_classes": low_count_classes,
        "blockers": blockers,
    }


def render_text(report: dict[str, Any]) -> str:
    summary = report["summary"]
    manifest = report["manifest"]
    overlap = report["reference_overlap"]
    lines = [
        "SILVAMANG candidate dataset readiness audit",
        "============================================",
        f"Ready for bulk promotion: {'YES' if report['ready'] else 'NO'}",
        f"Candidate root: {report['candidate_root']}",
        f"Classes: {summary['classes']}",
        f"Images: {summary['image_files']} ({summary['unique_hashes']} unique hashes)",
        (
            "Duplicates: "
            f"{summary['duplicate_groups']} groups, "
            f"{summary['cross_label_duplicate_groups']} cross-label, "
            f"{summary['cross_part_duplicate_groups']} cross-part"
        ),
        (
            "Manifest: "
            f"{manifest['rows']} rows, "
            f"{manifest['physical_files_matched_by_hash']} physical files matched, "
            f"{manifest['untracked_physical_files']} untracked"
        ),
        (
            "Reference overlap: "
            f"{overlap['unique_candidate_hashes']} unique hashes / "
            f"{overlap['candidate_files']} candidate files"
        ),
        "",
        "Per-class counts:",
    ]
    for species, values in report["per_class"].items():
        lines.append(
            f"- {species}: images={values['image_files']}, unique={values['unique_hashes']}, "
            f"approved_unique={values['approved_unique_hashes']}, "
            f"untracked={values['untracked_files']}"
        )

    lines.extend(("", "Blockers:"))
    if report["blockers"]:
        for blocker in report["blockers"]:
            lines.append(f"- {blocker['code']} ({blocker['count']}): {blocker['message']}")
    else:
        lines.append("- None")
    return "\n".join(lines)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read-only readiness audit for the SILVAMANG candidate image dataset."
    )
    parser.add_argument("--candidate-root", type=Path, default=DEFAULT_CANDIDATE_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument(
        "--staged-config",
        type=Path,
        default=DEFAULT_STAGED_CONFIG_PATH,
        help="Staged dataset policy that supplies the required per-class minimum.",
    )
    parser.add_argument(
        "--reference-root",
        action="append",
        type=Path,
        help="Image tree checked for exact overlap; repeat as needed.",
    )
    parser.add_argument(
        "--no-default-references",
        action="store_true",
        help="Do not compare against dataset/raw and the processed CNN dataset.",
    )
    parser.add_argument(
        "--minimum-approved-unique-images",
        type=int,
        help=(
            "Optional stricter per-class minimum. It cannot be lower than the staged "
            "dataset policy."
        ),
    )
    parser.add_argument("--json", action="store_true", help="Print the complete report as JSON.")
    args = parser.parse_args(argv)
    try:
        configured_minimum = configured_minimum_approved_unique_images(
            args.staged_config.resolve()
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))
    if args.minimum_approved_unique_images is None:
        args.minimum_approved_unique_images = configured_minimum
    elif args.minimum_approved_unique_images < configured_minimum:
        parser.error(
            "--minimum-approved-unique-images cannot be lower than the staged "
            f"dataset policy minimum ({configured_minimum})"
        )
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    references: list[Path] = [] if args.no_default_references else list(DEFAULT_REFERENCE_ROOTS)
    references.extend(args.reference_root or [])
    try:
        report = audit_candidate_dataset(
            args.candidate_root,
            args.manifest,
            project_root=PROJECT_ROOT,
            reference_roots=references,
            minimum_approved_unique_images_per_class=args.minimum_approved_unique_images,
            staged_config_path=args.staged_config,
        )
    except (OSError, csv.Error, ValueError) as error:
        print(f"Candidate dataset audit failed: {error}", file=sys.stderr)
        return 2

    print(json.dumps(report, indent=2) if args.json else render_text(report))
    return 0 if report["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
