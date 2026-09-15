from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


PROJECT_ROOT = Path(__file__).resolve().parents[2]
Image.MAX_IMAGE_PIXELS = 200_000_000


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a thumbnail sheet from a candidate CSV report.")
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--part", choices=("leaves", "bark", "roots", "flowers"))
    parser.add_argument("--limit", type=int, default=24)
    parser.add_argument("--columns", type=int, default=4)
    args = parser.parse_args()
    if args.limit < 1:
        parser.error("--limit must be positive")
    if not 1 <= args.columns <= 8:
        parser.error("--columns must be between 1 and 8")
    return args


def project_path(path: Path) -> Path:
    return path if path.is_absolute() else PROJECT_ROOT / path


def main() -> int:
    args = parse_args()
    input_path = project_path(args.input)
    output_path = project_path(args.output)
    with input_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if not args.part or row.get("suggested_part") == args.part
        ][: args.limit]

    if not rows:
        raise ValueError("No report rows match the requested contact sheet.")

    cell_width = 320
    image_height = 240
    label_height = 76
    gutter = 12
    rows_count = math.ceil(len(rows) / args.columns)
    sheet = Image.new(
        "RGB",
        (
            gutter + args.columns * (cell_width + gutter),
            gutter + rows_count * (image_height + label_height + gutter),
        ),
        "#e8eee9",
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for index, row in enumerate(rows):
        column = index % args.columns
        row_number = index // args.columns
        left = gutter + column * (cell_width + gutter)
        top = gutter + row_number * (image_height + label_height + gutter)
        image_path = project_path(Path(str(row.get("file_path") or "")))
        try:
            with Image.open(image_path) as source:
                preview = ImageOps.contain(source.convert("RGB"), (cell_width, image_height))
        except (OSError, ValueError):
            preview = Image.new("RGB", (cell_width, image_height), "#6c7770")
        image_left = left + (cell_width - preview.width) // 2
        image_top = top + (image_height - preview.height) // 2
        sheet.paste(preview, (image_left, image_top))

        label_lines = (
            str(row.get("candidate_id") or "")[:38],
            str(row.get("scientific_name") or "")[:38],
            f"{row.get('suggested_part', '')}  confidence={row.get('confidence', '')}",
        )
        label_top = top + image_height + 5
        draw.multiline_text(
            (left + 4, label_top),
            "\n".join(label_lines),
            fill="#17221d",
            font=font,
            spacing=4,
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="JPEG", quality=88, optimize=True)
    print(f"Contact sheet: {output_path} ({len(rows)} candidates)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
