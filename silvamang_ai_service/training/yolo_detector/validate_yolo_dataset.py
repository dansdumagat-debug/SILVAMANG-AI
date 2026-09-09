from pathlib import Path

try:
    from .config import (
        YOLO_CLASS_LABELS_PATH,
        YOLO_DETECTION_DATASET_PATH,
        YOLO_SEGMENTATION_DATASET_PATH,
    )
    from .utils import load_yolo_classes, summarize_yolo_split, validate_yolo_label_line
except ImportError:
    from config import (
        YOLO_CLASS_LABELS_PATH,
        YOLO_DETECTION_DATASET_PATH,
        YOLO_SEGMENTATION_DATASET_PATH,
    )
    from utils import load_yolo_classes, summarize_yolo_split, validate_yolo_label_line


def required_paths(dataset_path):
    paths = [dataset_path / "data.yaml"]
    for kind in ("images", "labels"):
        for split in ("train", "val", "test"):
            paths.append(dataset_path / kind / split)
    return paths


def validate_detection_labels(dataset_path, class_count):
    errors = []
    for label_file in (dataset_path / "labels").rglob("*.txt"):
        if label_file.name == ".gitkeep":
            continue
        for line_number, line in enumerate(label_file.read_text(encoding="utf-8").splitlines(), start=1):
            if not line.strip():
                continue
            is_valid, message = validate_yolo_label_line(line, class_count)
            if not is_valid:
                errors.append(f"{label_file}:{line_number} {message}")
    return errors


def validate_segmentation_labels(dataset_path, class_count):
    errors = []
    for label_file in (dataset_path / "labels").rglob("*.txt"):
        if label_file.name == ".gitkeep":
            continue
        for line_number, line in enumerate(label_file.read_text(encoding="utf-8").splitlines(), start=1):
            parts = line.strip().split()
            if not parts:
                continue
            try:
                class_id = int(parts[0])
            except ValueError:
                errors.append(f"{label_file}:{line_number} class_id must be an integer.")
                continue
            if class_id < 0 or class_id >= class_count:
                errors.append(f"{label_file}:{line_number} class_id must be between 0 and {class_count - 1}.")
            if len(parts) < 7:
                errors.append(f"{label_file}:{line_number} segmentation labels should include polygon points.")
    return errors


def validate_dataset(name, dataset_path, class_count, segmentation=False):
    print(f"\n{name}")
    print("=" * len(name))
    missing = [path for path in required_paths(dataset_path) if not path.exists()]
    if missing:
        for path in missing:
            print(f"Missing: {path}")
        return False

    summary = summarize_yolo_split(dataset_path)
    total_images = 0
    total_labels = 0
    for split, counts in summary.items():
        total_images += counts["images"]
        total_labels += counts["labels"]
        print(f"{split}: images={counts['images']} labels={counts['labels']}")

    if total_images == 0:
        print("Warning: image count is 0.")
    if total_labels == 0:
        print("Warning: labels are missing.")

    errors = validate_segmentation_labels(dataset_path, class_count) if segmentation else validate_detection_labels(dataset_path, class_count)
    for error in errors:
        print(f"Invalid label: {error}")

    return not errors


def main():
    classes = load_yolo_classes(YOLO_CLASS_LABELS_PATH)
    if not classes:
        print(f"Missing YOLO classes at {YOLO_CLASS_LABELS_PATH}")
        raise SystemExit(1)

    detection_ok = validate_dataset("YOLO detection dataset", YOLO_DETECTION_DATASET_PATH, len(classes))
    segmentation_ok = validate_dataset("YOLO segmentation dataset", YOLO_SEGMENTATION_DATASET_PATH, len(classes), segmentation=True)

    detection_summary = summarize_yolo_split(YOLO_DETECTION_DATASET_PATH)
    segmentation_summary = summarize_yolo_split(YOLO_SEGMENTATION_DATASET_PATH)
    total_images = sum(item["images"] for item in detection_summary.values()) + sum(item["images"] for item in segmentation_summary.values())

    if total_images == 0:
        print("\nYOLO dataset is structurally ready but has no annotated images yet.")

    raise SystemExit(0 if detection_ok and segmentation_ok else 1)


if __name__ == "__main__":
    main()
