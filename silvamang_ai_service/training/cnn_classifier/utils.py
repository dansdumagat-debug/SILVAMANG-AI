import json
import random
from pathlib import Path


def load_species_labels(labels_path):
    labels_file = Path(labels_path)
    if not labels_file.exists():
        return []

    return [
        line.strip()
        for line in labels_file.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def save_json(data, path):
    output_path = Path(path)
    ensure_dir(output_path.parent)
    output_path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def get_device():
    import torch

    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def count_images_by_split(processed_dir):
    image_extensions = {".jpg", ".jpeg", ".png", ".webp"}
    processed_path = Path(processed_dir)
    counts = {}

    for split in ("train", "val", "test"):
        split_path = processed_path / split
        counts[split] = sum(
            1
            for image_path in split_path.rglob("*")
            if image_path.is_file() and image_path.suffix.lower() in image_extensions
        )

    return counts


def compute_top_k_accuracy(outputs, labels, k=3):
    _, predictions = outputs.topk(k, dim=1)
    correct = predictions.eq(labels.view(-1, 1).expand_as(predictions))
    return correct.any(dim=1).float().mean().item()


def set_seed(seed):
    random.seed(seed)

    try:
        import numpy as np

        np.random.seed(seed)
    except ImportError:
        pass

    try:
        import torch

        torch.manual_seed(seed)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(seed)
    except ImportError:
        pass
