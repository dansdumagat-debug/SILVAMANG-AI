import argparse
import csv
import time
from datetime import datetime, timezone
from pathlib import Path

import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import accuracy_score, precision_recall_fscore_support
from torch.utils.data import DataLoader
from torchvision import datasets, models, transforms
from tqdm import tqdm

try:
    from .experiment_artifacts import (
        DEFAULT_DATASET_ROOT,
        RUNTIME_IMAGE_SIZE,
        RUNTIME_RESIZE_SIZE,
        dataset_fingerprint,
        file_sha256,
        initialize_training_run,
        require_same_dataset_fingerprint,
        timestamped_run_dir,
        assert_path_outside_dataset,
        validate_dataset_class_order,
        write_json,
    )
except ImportError:
    from experiment_artifacts import (
        DEFAULT_DATASET_ROOT,
        RUNTIME_IMAGE_SIZE,
        RUNTIME_RESIZE_SIZE,
        dataset_fingerprint,
        file_sha256,
        initialize_training_run,
        require_same_dataset_fingerprint,
        timestamped_run_dir,
        assert_path_outside_dataset,
        validate_dataset_class_order,
        write_json,
    )

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def save_json(data: dict | list, path: Path) -> None:
    write_json(data, path)


def get_device() -> torch.device:
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def set_seed(seed: int) -> None:
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def build_transforms(image_size: int) -> tuple[transforms.Compose, transforms.Compose]:
    if image_size != RUNTIME_IMAGE_SIZE:
        raise ValueError(
            f"EfficientNet preprocessing requires image_size={RUNTIME_IMAGE_SIZE}."
        )
    train_transform = transforms.Compose(
        [
            transforms.RandomResizedCrop(image_size),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(degrees=15),
            transforms.ColorJitter(
                brightness=0.2,
                contrast=0.2,
                saturation=0.2,
                hue=0.05,
            ),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )

    val_transform = transforms.Compose(
        [
            transforms.Resize(RUNTIME_RESIZE_SIZE),
            transforms.CenterCrop(image_size),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )

    return train_transform, val_transform


def build_model(model_name: str, num_classes: int, *, pretrained: bool = True) -> nn.Module:
    normalized_name = model_name.lower()
    if normalized_name != "efficientnet_b0":
        raise ValueError("Only efficientnet_b0 is supported in this script.")

    if pretrained:
        try:
            weights = models.EfficientNet_B0_Weights.DEFAULT
            model = models.efficientnet_b0(weights=weights)
        except AttributeError:
            model = models.efficientnet_b0(pretrained=True)
    else:
        try:
            model = models.efficientnet_b0(weights=None)
        except TypeError:
            model = models.efficientnet_b0(pretrained=False)

    in_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(in_features, num_classes)
    return model


def class_weights_from_targets(targets: list[int], num_classes: int) -> torch.Tensor:
    counts = torch.bincount(torch.tensor(targets), minlength=num_classes).float()
    safe_counts = torch.clamp(counts, min=1.0)
    weights = safe_counts.sum() / (num_classes * safe_counts)
    return weights


def run_epoch(
    model: nn.Module,
    dataloader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
    optimizer: optim.Optimizer | None = None,
) -> dict:
    training = optimizer is not None
    model.train(training)

    running_loss = 0.0
    all_labels: list[int] = []
    all_predictions: list[int] = []

    with torch.set_grad_enabled(training):
        for images, labels in tqdm(dataloader, leave=False):
            images = images.to(device)
            labels = labels.to(device)

            if training:
                optimizer.zero_grad()

            outputs = model(images)
            loss = criterion(outputs, labels)

            if training:
                loss.backward()
                optimizer.step()

            running_loss += loss.item() * images.size(0)
            predictions = outputs.argmax(dim=1)
            all_labels.extend(labels.cpu().tolist())
            all_predictions.extend(predictions.cpu().tolist())

    accuracy = accuracy_score(all_labels, all_predictions) if all_labels else 0.0
    precision, recall, f1, _ = precision_recall_fscore_support(
        all_labels,
        all_predictions,
        average="macro",
        zero_division=0,
    )

    return {
        "loss": running_loss / max(len(all_labels), 1),
        "accuracy": accuracy,
        "macro_precision": precision,
        "macro_recall": recall,
        "macro_f1": f1,
    }


def append_history_row(path: Path, row: dict) -> None:
    ensure_dir(path.parent)
    file_exists = path.exists()
    with path.open("a", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(row.keys()))
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Train a SILVAMANG AI EfficientNet experiment in an isolated, versioned run. "
            "The active server and Flutter model assets are never overwritten."
        )
    )
    parser.add_argument(
        "--dataset-root",
        type=Path,
        default=DEFAULT_DATASET_ROOT,
        help="Dataset root containing train/, val/, and held-out test/ directories.",
    )
    parser.add_argument(
        "--run-dir",
        type=Path,
        help=(
            "New, empty staging run directory. When omitted, a UTC timestamped directory "
            "is created under silvamang_ai_service/artifacts/efficientnet_transfer."
        ),
    )
    parser.add_argument(
        "--expected-class-order",
        type=Path,
        help=(
            "Optional class-order JSON to enforce. A class_order.json at the dataset root "
            "is enforced automatically when present."
        ),
    )
    parser.add_argument(
        "--allow-legacy-dataset",
        action="store_true",
        help=(
            "Explicitly allow a legacy dataset without the staged-builder evidence bundle. "
            "This is forbidden for the 29-class or unknown-class workflow."
        ),
    )
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--model", default="efficientnet_b0")
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--patience", type=int, default=7)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--num-workers", type=int, default=2)
    return parser


def main() -> None:
    args = build_argument_parser().parse_args()

    if args.epochs < 1:
        raise ValueError("--epochs must be at least 1.")
    if args.batch_size < 1:
        raise ValueError("--batch-size must be at least 1.")
    if args.image_size != RUNTIME_IMAGE_SIZE:
        raise ValueError(
            f"--image-size must be exactly {RUNTIME_IMAGE_SIZE} because the server and "
            "Flutter preprocessing contracts are fixed to that size."
        )
    if args.num_workers < 0:
        raise ValueError("--num-workers cannot be negative.")

    dataset_root = args.dataset_root.expanduser().resolve()
    run_dir = assert_path_outside_dataset(
        args.run_dir or timestamped_run_dir(),
        dataset_root,
        label="Training run directory",
    )
    class_order = validate_dataset_class_order(
        dataset_root,
        splits=("train", "val", "test"),
        expected_class_order_path=args.expected_class_order,
        allow_legacy_dataset=args.allow_legacy_dataset,
    )
    dataset_contract = (
        "staged_builder_v1"
        if (dataset_root / "BUILD_COMPLETE.json").is_file()
        else "legacy_explicit"
    )
    initial_dataset_fingerprint = dataset_fingerprint(dataset_root)
    paths = initialize_training_run(run_dir)

    train_dir = dataset_root / "train"
    val_dir = dataset_root / "val"

    set_seed(args.seed)

    train_transform, val_transform = build_transforms(args.image_size)
    train_dataset = datasets.ImageFolder(train_dir, transform=train_transform)
    val_dataset = datasets.ImageFolder(val_dir, transform=val_transform)

    if train_dataset.classes != class_order or val_dataset.classes != class_order:
        raise RuntimeError(
            "Dataset class order changed after validation. Stop the run and rebuild the "
            "versioned dataset before training."
        )

    save_json(class_order, paths.class_order)
    save_json(
        {
            "schema_version": 1,
            "status": "training",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "dataset_root": str(dataset_root),
            "run_dir": str(paths.run_dir),
            "class_count": len(class_order),
            "class_order": class_order,
            "dataset_contract": dataset_contract,
            "dataset_fingerprint": initial_dataset_fingerprint,
            "training": {
                "model": args.model,
                "epochs": args.epochs,
                "batch_size": args.batch_size,
                "image_size": args.image_size,
                "learning_rate": args.learning_rate,
                "weight_decay": args.weight_decay,
                "patience": args.patience,
                "seed": args.seed,
                "num_workers": args.num_workers,
            },
        },
        paths.run_manifest,
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        pin_memory=torch.cuda.is_available(),
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
        pin_memory=torch.cuda.is_available(),
    )

    device = get_device()
    model = build_model(args.model, num_classes=len(train_dataset.classes)).to(device)
    class_weights = class_weights_from_targets(train_dataset.targets, len(train_dataset.classes)).to(device)
    criterion = nn.CrossEntropyLoss(weight=class_weights)
    optimizer = optim.AdamW(
        model.parameters(),
        lr=args.learning_rate,
        weight_decay=args.weight_decay,
    )
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer,
        mode="max",
        factor=0.5,
        patience=2,
    )

    best_macro_f1 = -1.0
    best_metrics: dict = {}
    epochs_without_improvement = 0
    started_at = time.strftime("%Y-%m-%d %H:%M:%S")

    for epoch in range(1, args.epochs + 1):
        train_metrics = run_epoch(model, train_loader, criterion, device, optimizer)
        val_metrics = run_epoch(model, val_loader, criterion, device)
        scheduler.step(val_metrics["macro_f1"])

        row = {
            "epoch": epoch,
            "train_loss": train_metrics["loss"],
            "val_loss": val_metrics["loss"],
            "val_accuracy": val_metrics["accuracy"],
            "val_macro_precision": val_metrics["macro_precision"],
            "val_macro_recall": val_metrics["macro_recall"],
            "val_macro_f1": val_metrics["macro_f1"],
            "learning_rate": optimizer.param_groups[0]["lr"],
        }
        append_history_row(paths.training_history, row)

        print(
            f"Epoch {epoch}/{args.epochs} "
            f"train_loss={train_metrics['loss']:.4f} "
            f"val_loss={val_metrics['loss']:.4f} "
            f"val_accuracy={val_metrics['accuracy']:.4f} "
            f"val_macro_precision={val_metrics['macro_precision']:.4f} "
            f"val_macro_recall={val_metrics['macro_recall']:.4f} "
            f"val_macro_f1={val_metrics['macro_f1']:.4f}"
        )

        if val_metrics["macro_f1"] > best_macro_f1:
            best_macro_f1 = val_metrics["macro_f1"]
            best_metrics = {
                "model": args.model,
                "classes": class_order,
                "image_size": args.image_size,
                "best_epoch": epoch,
                "best_val_macro_f1": best_macro_f1,
                "val_accuracy": val_metrics["accuracy"],
                "val_macro_precision": val_metrics["macro_precision"],
                "val_macro_recall": val_metrics["macro_recall"],
                "val_loss": val_metrics["loss"],
                "started_at": started_at,
                "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
            torch.save(
                {
                    "model_name": args.model,
                    "model_state_dict": model.state_dict(),
                    "classes": class_order,
                    "image_size": args.image_size,
                    "best_val_macro_f1": best_macro_f1,
                    "best_epoch": epoch,
                },
                paths.checkpoint,
            )
            save_json(best_metrics, paths.validation_metrics)
            epochs_without_improvement = 0
        else:
            epochs_without_improvement += 1

        if epochs_without_improvement >= args.patience:
            print(f"Early stopping after {args.patience} epochs without validation macro F1 improvement.")
            break

    if not paths.checkpoint.is_file():
        raise RuntimeError("Training ended without producing a best checkpoint.")

    final_dataset_fingerprint = dataset_fingerprint(dataset_root)
    require_same_dataset_fingerprint(
        initial_dataset_fingerprint,
        final_dataset_fingerprint,
        expected_name="dataset at training start",
        actual_name="dataset at training completion",
    )

    completed_at = datetime.now(timezone.utc).isoformat()
    manifest = {
        "schema_version": 1,
        "status": "complete",
        "created_at": started_at,
        "completed_at": completed_at,
        "dataset_root": str(dataset_root),
        "run_dir": str(paths.run_dir),
        "class_count": len(class_order),
        "class_order": class_order,
        "dataset_contract": dataset_contract,
        "image_size": args.image_size,
        "dataset_fingerprint": final_dataset_fingerprint,
        "checkpoint": str(paths.checkpoint),
        "checkpoint_sha256": file_sha256(paths.checkpoint),
        "class_order_sha256": file_sha256(paths.class_order),
        "validation_metrics": str(paths.validation_metrics),
        "best_epoch": best_metrics.get("best_epoch"),
        "best_val_macro_f1": best_metrics.get("best_val_macro_f1"),
    }
    save_json(manifest, paths.run_manifest)
    paths.incomplete_marker.unlink(missing_ok=True)
    save_json(manifest, paths.complete_marker)

    print(f"Experiment run: {paths.run_dir}")
    print(f"Best checkpoint saved to: {paths.checkpoint}")
    print(f"Class order saved to: {paths.class_order}")
    print(f"Training history saved to: {paths.training_history}")
    print(f"Validation metrics saved to: {paths.validation_metrics}")


if __name__ == "__main__":
    main()
