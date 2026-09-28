from __future__ import annotations

import argparse
import csv
import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from tempfile import NamedTemporaryFile

try:
    from .candidate_manifest_lock import candidate_manifest_write_lock
    from .candidate_manifest_paths import CandidatePathResolver, normalize_part, part_hint_from_path
except ImportError:
    from candidate_manifest_lock import candidate_manifest_write_lock
    from candidate_manifest_paths import CandidatePathResolver, normalize_part, part_hint_from_path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = PROJECT_ROOT / "dataset" / "metadata" / "candidate_image_manifest.csv"
DEFAULT_CANDIDATE_ROOT = PROJECT_ROOT / "dataset" / "candidates"


@dataclass
class ReconciliationReport:
    rows: int = 0
    already_current: int = 0
    repairable: int = 0
    ambiguous: int = 0
    unresolved: int = 0
    changed: int = 0


def _relative_to_project(path: Path, project_root: Path) -> str:
    return path.resolve().relative_to(project_root.resolve()).as_posix()


def _recorded_path(row: dict[str, str], project_root: Path, candidate_root: Path) -> Path | None:
    value = str(row.get("file_path") or "").strip()
    if not value:
        return None
    relative = Path(value)
    if relative.is_absolute():
        return None
    resolved = (project_root / relative).resolve()
    try:
        resolved.relative_to(candidate_root.resolve())
    except ValueError:
        return None
    return resolved if resolved.is_file() else None


def select_unambiguous_path(
    row: dict[str, str],
    matches: list[Path],
    project_root: Path,
    candidate_root: Path,
) -> Path | None:
    current = _recorded_path(row, project_root, candidate_root)
    if current is not None and current in matches:
        return current
    if len(matches) == 1:
        return matches[0]

    reviewed_part = normalize_part(str(row.get("reviewed_plant_part") or ""))
    if reviewed_part:
        part_matches = [path for path in matches if part_hint_from_path(path) == reviewed_part]
        if len(part_matches) == 1:
            return part_matches[0]
    return None


def reconcile_rows(
    rows: list[dict[str, str]],
    resolver: CandidatePathResolver,
    project_root: Path,
    candidate_root: Path,
    apply_changes: bool,
) -> ReconciliationReport:
    report = ReconciliationReport(rows=len(rows))
    for row in rows:
        matches = resolver.resolve_all(row)
        if not matches:
            report.unresolved += 1
            continue

        selected = select_unambiguous_path(row, matches, project_root, candidate_root)
        if selected is None:
            report.ambiguous += 1
            continue

        relative = _relative_to_project(selected, project_root)
        if str(row.get("file_path") or "").replace("\\", "/") == relative:
            report.already_current += 1
            continue

        report.repairable += 1
        if apply_changes:
            row["file_path"] = relative
            report.changed += 1
    return report


def write_manifest_atomic(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with NamedTemporaryFile(
        "w",
        encoding="utf-8",
        newline="",
        dir=path.parent,
        prefix="candidate_manifest_reconciled_",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        writer = csv.DictWriter(temporary, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Repair stale candidate manifest paths using candidate ID, species folder, and SHA-256. "
            "The default is a dry run; ambiguous or missing files are never guessed."
        )
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--candidate-root", type=Path, default=DEFAULT_CANDIDATE_ROOT)
    parser.add_argument("--apply", action="store_true", help="Atomically write unambiguous repairs.")
    parser.add_argument("--json", action="store_true", help="Print the summary as JSON.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = args.manifest.resolve()
    candidate_root = args.candidate_root.resolve()
    if not manifest.is_file():
        raise FileNotFoundError(f"Candidate manifest not found: {manifest}")
    if not candidate_root.is_dir():
        raise FileNotFoundError(f"Candidate root not found: {candidate_root}")

    def plan() -> tuple[list[str], list[dict[str, str]], ReconciliationReport]:
        with manifest.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fieldnames = list(reader.fieldnames or [])
            rows = list(reader)
        required = {"candidate_id", "file_path", "scientific_name", "sha256"}
        missing = sorted(required - set(fieldnames))
        if missing:
            raise ValueError(
                "Candidate manifest is missing required columns: " + ", ".join(missing)
            )
        resolver = CandidatePathResolver(PROJECT_ROOT, candidate_root)
        report = reconcile_rows(
            rows,
            resolver,
            PROJECT_ROOT,
            candidate_root,
            apply_changes=args.apply,
        )
        return fieldnames, rows, report

    if args.apply:
        with candidate_manifest_write_lock(manifest):
            fieldnames, rows, report = plan()
            if report.changed:
                write_manifest_atomic(manifest, fieldnames, rows)
    else:
        _, _, report = plan()

    payload = {"mode": "apply" if args.apply else "dry-run", **asdict(report)}
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"Candidate manifest path reconciliation ({payload['mode']})")
        for key, value in asdict(report).items():
            print(f"- {key.replace('_', ' ')}: {value}")
        if not args.apply and report.repairable:
            print("Run again with --apply to write the unambiguous repairs.")
        if report.ambiguous or report.unresolved:
            print("Ambiguous and unresolved rows require manual review; no path was guessed.")

    return 1 if report.ambiguous or report.unresolved else 0


if __name__ == "__main__":
    raise SystemExit(main())
