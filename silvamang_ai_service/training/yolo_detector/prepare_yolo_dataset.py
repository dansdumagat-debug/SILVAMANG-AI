import argparse
import csv
import hashlib
import re
import shutil
from pathlib import Path

try:
    from .config import PROJECT_ROOT, RANDOM_SEED, YOLO_CLASS_LABELS_PATH, YOLO_DETECTION_DATASET_PATH
    from .utils import IMAGE_EXTENSIONS, ensure_dir, load_yolo_classes
except ImportError:
    from config import PROJECT_ROOT, RANDOM_SEED, YOLO_CLASS_LABELS_PATH, YOLO_DETECTION_DATASET_PATH
    from utils import IMAGE_EXTENSIONS, ensure_dir, load_yolo_classes


PART_FOLDER_ALIASES = {
    "leaf": "leaves",
    "leaves": "leaves",
    "bark": "bark",
    "root": "roots",
    "roots": "roots",
    "flower": "flowers",
    "flowers": "flowers",
    "canopy": "canopy",
    "tree": "full_tree",
    "full_tree": "full_tree",
    "whole_tree": "full_tree",
}


def split_for_path(path):
    digest = hashlib.sha1(f"{RANDOM_SEED}:{path.as_posix()}".encode("utf-8")).hexdigest()
    bucket = int(digest[:8], 16) / 0xFFFFFFFF

    if bucket < 0.8:
        return "train"

    if bucket < 0.9:
        return "val"

    return "test"


def infer_part_class(path, class_to_id):
    for part in reversed(path.parts):
        class_name = PART_FOLDER_ALIASES.get(part.lower())
        if class_name in class_to_id:
            return class_name

    return None


def output_stem(raw_root, image_path, class_name):
    relative_path = image_path.relative_to(raw_root)
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "_", relative_path.with_suffix("").as_posix())
    digest = hashlib.sha1(relative_path.as_posix().encode("utf-8")).hexdigest()[:10]
    max_slug_length = max(20, 140 - len(class_name) - len(digest))

    return f"{class_name}_{slug[:max_slug_length]}_{digest}"


def build_weak_dataset(max_per_class):
    raw_root = PROJECT_ROOT / "dataset" / "raw"
    class_names = load_yolo_classes(YOLO_CLASS_LABELS_PATH)
    class_to_id = {name: index for index, name in enumerate(class_names)}

    if not raw_root.exists():
        print(f"Raw dataset not found: {raw_root}")
        return

    if not class_to_id:
        print(f"YOLO class list not found: {YOLO_CLASS_LABELS_PATH}")
        return

    per_class_counts = {name: 0 for name in class_names}
    split_counts = {
        "train": {"images": 0, "labels": 0},
        "val": {"images": 0, "labels": 0},
        "test": {"images": 0, "labels": 0},
    }
    manifest_rows = []

    for split in ("train", "val", "test"):
        ensure_dir(YOLO_DETECTION_DATASET_PATH / "images" / split)
        ensure_dir(YOLO_DETECTION_DATASET_PATH / "labels" / split)

    image_paths = sorted(
        path for path in raw_root.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )

    for image_path in image_paths:
        class_name = infer_part_class(image_path, class_to_id)

        if class_name is None:
            continue

        if max_per_class > 0 and per_class_counts[class_name] >= max_per_class:
            continue

        split = split_for_path(image_path)
        stem = output_stem(raw_root, image_path, class_name)
        output_image = YOLO_DETECTION_DATASET_PATH / "images" / split / f"{stem}{image_path.suffix.lower()}"
        output_label = YOLO_DETECTION_DATASET_PATH / "labels" / split / f"{stem}.txt"

        shutil.copy2(image_path, output_image)
        output_label.write_text(f"{class_to_id[class_name]} 0.500000 0.500000 1.000000 1.000000\n", encoding="utf-8")

        per_class_counts[class_name] += 1
        split_counts[split]["images"] += 1
        split_counts[split]["labels"] += 1
        manifest_rows.append([
            image_path.relative_to(PROJECT_ROOT).as_posix(),
            output_image.relative_to(PROJECT_ROOT).as_posix(),
            output_label.relative_to(PROJECT_ROOT).as_posix(),
            class_name,
            split,
            "weak_full_image_box",
        ])

    manifest_path = YOLO_DETECTION_DATASET_PATH / "weak_labels_manifest.csv"
    with manifest_path.open("w", newline="", encoding="utf-8") as manifest_file:
        writer = csv.writer(manifest_file)
        writer.writerow(["source_image", "output_image", "output_label", "class_name", "split", "label_type"])
        writer.writerows(manifest_rows)

    print("Weak YOLO detection dataset prepared.")
    print("Label type: full-image boxes from verified plant-part folders.")
    print("Use this only as a starter detector. Replace with hand-reviewed bounding boxes for accuracy.")
    print(f"Manifest: {manifest_path}")

    for split, counts in split_counts.items():
        print(f"{split}: images={counts['images']} labels={counts['labels']}")


def main():
    parser = argparse.ArgumentParser(description="Prepare YOLOv8 detector dataset.")
    parser.add_argument(
        "--weak-from-raw",
        action="store_true",
        help="Create weak full-image YOLO boxes from dataset/raw plant-part folders.",
    )
    parser.add_argument(
        "--max-per-class",
        type=int,
        default=0,
        help="Optional maximum source images to copy per YOLO class. Use 0 for all available images.",
    )
    args = parser.parse_args()

    if args.weak_from_raw:
        build_weak_dataset(args.max_per_class)
        return

    print("Prepare YOLO dataset after bounding-box annotations are completed.")
    print(f"Expected image source: {PROJECT_ROOT / 'dataset' / 'raw'}")
    print(f"Expected annotation source: {PROJECT_ROOT / 'dataset' / 'annotations' / 'yolo'}")
    print("Expected output folders:")
    for split in ("train", "val", "test"):
        print(f"- {YOLO_DETECTION_DATASET_PATH / 'images' / split}")
        print(f"- {YOLO_DETECTION_DATASET_PATH / 'labels' / split}")
    print("Automatic copying is disabled until annotation files exist and are reviewed.")
    print("No files were moved, copied, or fabricated.")
    print("Starter option: rerun with --weak-from-raw to create weak full-image labels from plant-part folders.")


if __name__ == "__main__":
    main()
