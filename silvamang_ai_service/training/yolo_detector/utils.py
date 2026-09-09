import json
from pathlib import Path


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def load_yolo_classes(labels_path):
    path = Path(labels_path)
    if not path.exists():
        return []

    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def count_images(path):
    folder = Path(path)
    if not folder.exists():
        return 0

    return sum(1 for item in folder.rglob("*") if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS)


def count_label_files(path):
    folder = Path(path)
    if not folder.exists():
        return 0

    return sum(1 for item in folder.rglob("*.txt") if item.is_file())


def validate_yolo_label_line(line, class_count):
    parts = line.strip().split()
    if len(parts) != 5:
        return False, "Detection labels must have 5 values: class_id x_center y_center width height."

    try:
        class_id = int(parts[0])
    except ValueError:
        return False, "class_id must be an integer."

    if class_id < 0 or class_id >= class_count:
        return False, f"class_id must be between 0 and {class_count - 1}."

    try:
        values = [float(value) for value in parts[1:]]
    except ValueError:
        return False, "Bounding-box coordinates must be numeric."

    if any(value < 0 or value > 1 for value in values):
        return False, "Bounding-box coordinates must be normalized from 0 to 1."

    return True, ""


def summarize_yolo_split(dataset_path):
    dataset = Path(dataset_path)
    summary = {}

    for split in ("train", "val", "test"):
        summary[split] = {
            "images": count_images(dataset / "images" / split),
            "labels": count_label_files(dataset / "labels" / split),
        }

    return summary


def write_json(data, path):
    output_path = Path(path)
    ensure_dir(output_path.parent)
    output_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
