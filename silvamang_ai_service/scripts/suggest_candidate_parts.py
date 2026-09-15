from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path

from ultralytics import YOLO


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = PROJECT_ROOT / "dataset" / "metadata" / "candidate_image_manifest.csv"
DEFAULT_MODEL_PATH = (
    PROJECT_ROOT
    / "silvamang_ai_service"
    / "reports"
    / "yolo_detector"
    / "detection"
    / "weights"
    / "best.pt"
)
PART_CLASS_IDS = {"leaves": 0, "bark": 1, "roots": 2, "flowers": 3}
REPORT_FIELDS = (
    "candidate_id",
    "scientific_name",
    "suggested_part",
    "confidence",
    "file_path",
    "source",
    "source_record_url",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Rank pending, unclassified candidates with the weak YOLO plant-part model. "
            "Results are suggestions only and never approve or move images."
        )
    )
    parser.add_argument(
        "--part",
        action="append",
        choices=tuple(PART_CLASS_IDS),
        required=True,
        help="Plant part to include; repeat for multiple parts.",
    )
    parser.add_argument("--species", action="append", help="Optional exact scientific name filter.")
    parser.add_argument("--confidence", type=float, default=0.70)
    parser.add_argument("--limit", type=int, default=0, help="Maximum images to scan; 0 scans all.")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL_PATH)
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / "dataset" / "metadata" / "visual_part_suggestions.csv",
    )
    args = parser.parse_args()
    if not 0.01 <= args.confidence <= 1.0:
        parser.error("--confidence must be between 0.01 and 1.0")
    if args.limit < 0:
        parser.error("--limit cannot be negative")
    return args


def pending_unclassified_rows(species_filter: set[str]) -> list[dict[str, str]]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Candidate manifest not found: {MANIFEST_PATH}")

    selected: list[dict[str, str]] = []
    with MANIFEST_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if str(row.get("review_status") or "pending").casefold() != "pending":
                continue
            if species_filter and str(row.get("scientific_name") or "") not in species_filter:
                continue
            relative_path = Path(str(row.get("file_path") or ""))
            if relative_path.parent.name != "unclassified":
                continue
            image_path = (PROJECT_ROOT / relative_path).resolve()
            if not image_path.is_file():
                continue
            row["_absolute_path"] = str(image_path)
            selected.append(row)
    return selected


def write_report(path: Path, suggestions: list[dict[str, str]]) -> None:
    path = path if path.is_absolute() else PROJECT_ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REPORT_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(suggestions)


def main() -> int:
    args = parse_args()
    model_path = args.model if args.model.is_absolute() else PROJECT_ROOT / args.model
    if not model_path.is_file():
        raise FileNotFoundError(f"YOLO model not found: {model_path}")

    requested_parts = list(dict.fromkeys(args.part))
    requested_ids = {PART_CLASS_IDS[part] for part in requested_parts}
    class_to_part = {class_id: part for part, class_id in PART_CLASS_IDS.items()}
    rows = pending_unclassified_rows(set(args.species or []))
    if args.limit:
        rows = rows[: args.limit]

    print(
        f"Scanning {len(rows)} pending unclassified candidates for "
        f"{', '.join(requested_parts)} (confidence >= {args.confidence:.2f})...",
        flush=True,
    )
    if not rows:
        write_report(args.output, [])
        return 0

    model = YOLO(str(model_path))
    results = model.predict(
        source=[row["_absolute_path"] for row in rows],
        stream=True,
        classes=sorted(requested_ids),
        conf=args.confidence,
        imgsz=640,
        verbose=False,
    )

    suggestions: list[dict[str, str]] = []
    for row, result in zip(rows, results, strict=True):
        boxes = result.boxes
        if boxes is None or len(boxes) == 0:
            continue
        candidates = [
            (float(confidence), int(class_id))
            for confidence, class_id in zip(boxes.conf.tolist(), boxes.cls.tolist(), strict=True)
            if int(class_id) in requested_ids
        ]
        if not candidates:
            continue
        confidence, class_id = max(candidates)
        suggestions.append(
            {
                "candidate_id": str(row.get("candidate_id") or ""),
                "scientific_name": str(row.get("scientific_name") or ""),
                "suggested_part": class_to_part[class_id],
                "confidence": f"{confidence:.6f}",
                "file_path": str(row.get("file_path") or ""),
                "source": str(row.get("source") or ""),
                "source_record_url": str(row.get("source_record_url") or ""),
            }
        )

    suggestions.sort(key=lambda item: float(item["confidence"]), reverse=True)
    write_report(args.output, suggestions)
    counts = Counter(item["suggested_part"] for item in suggestions)
    print(f"Suggestions: {len(suggestions)}", flush=True)
    for part in requested_parts:
        print(f"  {part}: {counts[part]}", flush=True)
    print(f"Report: {args.output}", flush=True)
    print("These are weak-model suggestions. Inspect every image before assigning a part.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
