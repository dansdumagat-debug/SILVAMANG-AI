import argparse
import random
import shutil
from pathlib import Path

try:
    from .config import (
        LABELS_PATH,
        PROCESSED_DATASET_PATH,
        RANDOM_SEED,
        RAW_DATASET_PATH,
        TEST_SPLIT,
        TRAIN_SPLIT,
        VAL_SPLIT,
    )
    from .utils import ensure_dir, load_species_labels
except ImportError:
    from config import (
        LABELS_PATH,
        PROCESSED_DATASET_PATH,
        RANDOM_SEED,
        RAW_DATASET_PATH,
        TEST_SPLIT,
        TRAIN_SPLIT,
        VAL_SPLIT,
    )
    from utils import ensure_dir, load_species_labels


SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SPLITS = ("train", "val", "test")
OFFICIAL_SPECIES_LABELS = [
    "Avicennia_marina",
    "Avicennia_marina_var_rumphiana",
    "Bruguiera_gymnorrhiza",
    "Ceriops_tagal",
    "Excoecaria_agallocha",
    "Rhizophora_apiculata",
    "Rhizophora_mucronata",
    "Rhizophora_stylosa",
    "Sonneratia_alba",
    "Xylocarpus_granatum",
]


def species_folder_name(species_name):
    return species_name.strip().replace(" ", "_")


def collect_species_images(raw_dir, species_name):
    species_dir = raw_dir / species_folder_name(species_name)

    if not species_dir.exists():
        return []

    return sorted(
        path
        for path in species_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
    )


def split_images(images):
    shuffled = list(images)
    random.Random(RANDOM_SEED).shuffle(shuffled)

    total = len(shuffled)
    train_count = int(total * TRAIN_SPLIT)
    val_count = int(total * VAL_SPLIT)

    if total > 0 and train_count == 0:
        train_count = 1

    test_count = total - train_count - val_count
    if total >= 3 and test_count == 0:
        test_count = 1
        if val_count > 0:
            val_count -= 1
        elif train_count > 1:
            train_count -= 1

    train_items = shuffled[:train_count]
    val_items = shuffled[train_count : train_count + val_count]
    test_items = shuffled[train_count + val_count :]

    return {"train": train_items, "val": val_items, "test": test_items}


def destination_for(source_path, split, species_name):
    species_dir = PROCESSED_DATASET_PATH / split / species_folder_name(species_name)
    return species_dir / source_path.name


def copy_split_files(split_map, species_name):
    copied = 0
    skipped = 0

    for split, images in split_map.items():
        split_species_dir = PROCESSED_DATASET_PATH / split / species_folder_name(species_name)
        ensure_dir(split_species_dir)

        for image_path in images:
            destination = destination_for(image_path, split, species_name)
            if destination.exists():
                skipped += 1
                continue

            shutil.copy2(image_path, destination)
            copied += 1

    return copied, skipped


def prepare_split(apply_changes=False):
    configured_labels = load_species_labels(LABELS_PATH)
    labels = OFFICIAL_SPECIES_LABELS
    if configured_labels and configured_labels != OFFICIAL_SPECIES_LABELS:
        print(f"WARNING: {LABELS_PATH} differs from the official 10-class list.")
        print("Using the official 10-class list for this split.")

    summary = {}
    total_images = 0
    empty_labels = []

    for species_name in labels:
        images = collect_species_images(RAW_DATASET_PATH, species_name)
        split_map = split_images(images)
        summary[species_name] = {split: len(items) for split, items in split_map.items()}
        total_images += len(images)
        if not images:
            empty_labels.append(species_name)

        if apply_changes:
            copy_split_files(split_map, species_name)

    mode = "APPLY" if apply_changes else "DRY RUN"
    print(f"CNN dataset split summary ({mode})")
    print(f"Source: {RAW_DATASET_PATH}")
    print(f"Target: {PROCESSED_DATASET_PATH}")
    print(f"Split ratios: train={TRAIN_SPLIT:.2f}, val={VAL_SPLIT:.2f}, test={TEST_SPLIT:.2f}")

    for species_name, counts in summary.items():
        total = counts["train"] + counts["val"] + counts["test"]
        print(
            f"- {species_name}: {total} images "
            f"(train={counts['train']}, val={counts['val']}, test={counts['test']})"
        )

    for species_name in empty_labels:
        print(f"WARNING: {species_name} has 0 images.")

    if total_images == 0:
        print("No images found in dataset/raw/. Add verified mangrove images before applying the CNN split.")
        return

    if not apply_changes:
        print("Dry run only. Run with --apply to copy files.")


def main():
    parser = argparse.ArgumentParser(description="Prepare CNN train/val/test folders.")
    parser.add_argument("--apply", action="store_true", help="Copy files into processed split folders.")
    args = parser.parse_args()

    if args.apply:
        for split in SPLITS:
            ensure_dir(PROCESSED_DATASET_PATH / split)

    prepare_split(apply_changes=args.apply)


if __name__ == "__main__":
    main()
