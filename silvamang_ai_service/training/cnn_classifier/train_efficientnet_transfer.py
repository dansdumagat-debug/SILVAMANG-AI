import argparse
import csv
import json
import time
from pathlib import Path

import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import accuracy_score, precision_recall_fscore_support
from torch.utils.data import DataLoader
from torchvision import datasets, models, transforms
from tqdm import tqdm


AI_SERVICE_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = AI_SERVICE_ROOT.parent
DATASET_ROOT = PROJECT_ROOT / "dataset" / "processed" / "cnn_classification"
MODEL_DIR = AI_SERVICE_ROOT / "models" / "cnn_classifier"
REPORT_DIR = AI_SERVICE_ROOT / "reports" / "efficientnet_transfer"
CHECKPOINT_PATH = MODEL_DIR / "efficientnet_b0_best.pth"
CLASS_ORDER_PATH = MODEL_DIR / "class_order.json"
HISTORY_CSV_PATH = REPORT_DIR / "training_history.csv"
VAL_METRICS_PATH = REPORT_DIR / "val_metrics.json"

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def save_json(data: dict | list, path: Path) -> None:
    ensure_dir(path.parent)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def get_device() -> torch.device:
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def set_seed(seed: int) -> None:
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def build_transforms(image_size: int) -> tuple[transforms.Compose, transforms.Compose]:
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
            transforms.Resize(int(image_size * 1.15)),
            transforms.CenterCrop(image_size),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )

    return train_transform, val_transform


def build_model(model_name: str, num_classes: int) -> nn.Module:
    normalized_name = model_name.lower()
    if normalized_name != "efficientnet_b0":
        raise ValueError("Only efficientnet_b0 is supported in this script.")

    try:
        weights = models.EfficientNet_B0_Weights.DEFAULT
        model = models.efficientnet_b0(weights=weights)
    except AttributeError:
        model = models.efficientnet_b0(pretrained=True)

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


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train SILVAMANG AI EfficientNet transfer-learning classifier."
    )
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--model", default="efficientnet_b0")
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--patience", type=int, default=7)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    train_dir = DATASET_ROOT / "train"
    val_dir = DATASET_ROOT / "val"
    if not train_dir.exists() or not val_dir.exists():
        raise FileNotFoundError("Expected train and val folders under dataset/processed/cnn_classification.")

    set_seed(args.seed)
    ensure_dir(MODEL_DIR)
    ensure_dir(REPORT_DIR)
    if HISTORY_CSV_PATH.exists():
        HISTORY_CSV_PATH.unlink()

    train_transform, val_transform = build_transforms(args.image_size)
    train_dataset = datasets.ImageFolder(train_dir, transform=train_transform)
    val_dataset = datasets.ImageFolder(val_dir, transform=val_transform)

    if len(train_dataset.classes) == 0:
        raise RuntimeError("No classes found in training dataset.")

    save_json(train_dataset.classes, CLASS_ORDER_PATH)

    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=2,
        pin_memory=torch.cuda.is_available(),
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=2,
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
        append_history_row(HISTORY_CSV_PATH, row)

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
                "classes": train_dataset.classes,
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
                    "classes": train_dataset.classes,
                    "image_size": args.image_size,
                    "best_val_macro_f1": best_macro_f1,
                    "best_epoch": epoch,
                },
                CHECKPOINT_PATH,
            )
            save_json(best_metrics, VAL_METRICS_PATH)
            epochs_without_improvement = 0
        else:
            epochs_without_improvement += 1

        if epochs_without_improvement >= args.patience:
            print(f"Early stopping after {args.patience} epochs without validation macro F1 improvement.")
            break

    print(f"Best checkpoint saved to: {CHECKPOINT_PATH}")
    print(f"Class order saved to: {CLASS_ORDER_PATH}")
    print(f"Training history saved to: {HISTORY_CSV_PATH}")
    print(f"Validation metrics saved to: {VAL_METRICS_PATH}")


if __name__ == "__main__":
    main()
