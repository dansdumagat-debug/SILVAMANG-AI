import csv
import json
from pathlib import Path

import matplotlib.pyplot as plt
import torch
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    precision_recall_fscore_support,
)
from torch.utils.data import DataLoader
from torchvision import datasets

try:
    from .train_efficientnet_transfer import (
        CHECKPOINT_PATH,
        CLASS_ORDER_PATH,
        DATASET_ROOT,
        REPORT_DIR,
        build_model,
        build_transforms,
        ensure_dir,
        get_device,
        save_json,
    )
except ImportError:
    from train_efficientnet_transfer import (
        CHECKPOINT_PATH,
        CLASS_ORDER_PATH,
        DATASET_ROOT,
        REPORT_DIR,
        build_model,
        build_transforms,
        ensure_dir,
        get_device,
        save_json,
    )


CONFUSION_MATRIX_PATH = REPORT_DIR / "confusion_matrix.png"
CLASSIFICATION_REPORT_PATH = REPORT_DIR / "classification_report.csv"
TEST_METRICS_PATH = REPORT_DIR / "test_metrics.json"


def load_class_order() -> list[str]:
    if not CLASS_ORDER_PATH.exists():
        raise FileNotFoundError(f"Class order file not found: {CLASS_ORDER_PATH}")
    return json.loads(CLASS_ORDER_PATH.read_text(encoding="utf-8"))


def save_confusion_matrix_plot(matrix, classes: list[str], path: Path) -> None:
    fig, ax = plt.subplots(figsize=(10, 8))
    image = ax.imshow(matrix, interpolation="nearest", cmap=plt.cm.Greens)
    fig.colorbar(image, ax=ax)
    ax.set(
        xticks=range(len(classes)),
        yticks=range(len(classes)),
        xticklabels=classes,
        yticklabels=classes,
        ylabel="Actual",
        xlabel="Predicted",
        title="EfficientNet-B0 Transfer Learning Confusion Matrix",
    )
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def save_classification_report_csv(report: dict, path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        fieldnames = ["class", "precision", "recall", "f1-score", "support"]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for class_name, values in report.items():
            if isinstance(values, dict):
                writer.writerow({"class": class_name, **values})


def main() -> None:
    if not CHECKPOINT_PATH.exists():
        raise FileNotFoundError("EfficientNet checkpoint not found. Run training first.")

    test_dir = DATASET_ROOT / "test"
    if not test_dir.exists():
        raise FileNotFoundError("Test folder not found under dataset/processed/cnn_classification.")

    ensure_dir(REPORT_DIR)
    classes = load_class_order()
    checkpoint = torch.load(CHECKPOINT_PATH, map_location="cpu")
    image_size = checkpoint.get("image_size", 224)
    _, test_transform = build_transforms(image_size)

    dataset = datasets.ImageFolder(test_dir, transform=test_transform)
    if dataset.classes != classes:
        raise RuntimeError(
            "Test class folder order does not match class_order.json. "
            "Do not evaluate until dataset class folders match training class order."
        )

    dataloader = DataLoader(dataset, batch_size=16, shuffle=False)
    device = get_device()
    model = build_model(checkpoint.get("model_name", "efficientnet_b0"), len(classes)).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    all_labels: list[int] = []
    all_predictions: list[int] = []

    with torch.no_grad():
        for images, labels in dataloader:
            images = images.to(device)
            labels = labels.to(device)
            outputs = model(images)
            predictions = outputs.argmax(dim=1)
            all_labels.extend(labels.cpu().tolist())
            all_predictions.extend(predictions.cpu().tolist())

    accuracy = accuracy_score(all_labels, all_predictions)
    macro_precision, macro_recall, macro_f1, _ = precision_recall_fscore_support(
        all_labels,
        all_predictions,
        average="macro",
        zero_division=0,
    )
    per_class_precision, per_class_recall, per_class_f1, per_class_support = (
        precision_recall_fscore_support(
            all_labels,
            all_predictions,
            labels=list(range(len(classes))),
            average=None,
            zero_division=0,
        )
    )

    matrix = confusion_matrix(all_labels, all_predictions, labels=list(range(len(classes))))
    save_confusion_matrix_plot(matrix, classes, CONFUSION_MATRIX_PATH)

    report = classification_report(
        all_labels,
        all_predictions,
        target_names=classes,
        output_dict=True,
        zero_division=0,
    )
    save_classification_report_csv(report, CLASSIFICATION_REPORT_PATH)

    metrics = {
        "accuracy": accuracy,
        "macro_precision": macro_precision,
        "macro_recall": macro_recall,
        "macro_f1": macro_f1,
        "classes": classes,
        "per_class": [
            {
                "class": class_name,
                "precision": float(per_class_precision[index]),
                "recall": float(per_class_recall[index]),
                "f1": float(per_class_f1[index]),
                "support": int(per_class_support[index]),
            }
            for index, class_name in enumerate(classes)
        ],
    }
    save_json(metrics, TEST_METRICS_PATH)

    print(f"test accuracy: {accuracy:.4f}")
    print(f"macro precision: {macro_precision:.4f}")
    print(f"macro recall: {macro_recall:.4f}")
    print(f"macro F1: {macro_f1:.4f}")
    print("per-class precision/recall/F1:")
    for row in metrics["per_class"]:
        print(
            f"- {row['class']}: "
            f"precision={row['precision']:.4f} "
            f"recall={row['recall']:.4f} "
            f"f1={row['f1']:.4f}"
        )


if __name__ == "__main__":
    main()
