import csv

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
    from .config import DEFAULT_BATCH_SIZE, MODEL_OUTPUT_PATH, PROCESSED_DATASET_PATH, REPORTS_OUTPUT_PATH
    from .model import BaselineCNN
    from .train_cnn_baseline import build_transforms
    from .utils import compute_top_k_accuracy, ensure_dir, get_device, save_json
except ImportError:
    from config import DEFAULT_BATCH_SIZE, MODEL_OUTPUT_PATH, PROCESSED_DATASET_PATH, REPORTS_OUTPUT_PATH
    from model import BaselineCNN
    from train_cnn_baseline import build_transforms
    from utils import compute_top_k_accuracy, ensure_dir, get_device, save_json


def save_confusion_matrix_csv(matrix, classes, path):
    with open(path, "w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["actual/predicted", *classes])
        for class_name, row in zip(classes, matrix):
            writer.writerow([class_name, *row.tolist()])


def save_confusion_matrix_plot(matrix, classes, path):
    fig, ax = plt.subplots(figsize=(9, 7))
    image = ax.imshow(matrix, interpolation="nearest", cmap=plt.cm.Greens)
    fig.colorbar(image, ax=ax)
    ax.set(
        xticks=range(len(classes)),
        yticks=range(len(classes)),
        xticklabels=classes,
        yticklabels=classes,
        ylabel="Actual",
        xlabel="Predicted",
        title="CNN Baseline Confusion Matrix",
    )
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def main():
    if not MODEL_OUTPUT_PATH.exists():
        print("Model file not found. Train the baseline CNN first.")
        return

    test_dir = PROCESSED_DATASET_PATH / "test"
    if not test_dir.exists() or not any(test_dir.rglob("*.*")):
        print("No test images found. Prepare dataset split first.")
        return

    ensure_dir(REPORTS_OUTPUT_PATH)

    device = get_device()
    checkpoint = torch.load(MODEL_OUTPUT_PATH, map_location=device)
    classes = checkpoint["classes"]
    image_size = checkpoint.get("image_size", 224)

    dataset = datasets.ImageFolder(test_dir, transform=build_transforms(image_size))
    if len(dataset) == 0:
        print("No test images found. Prepare dataset split first.")
        return

    dataloader = DataLoader(dataset, batch_size=DEFAULT_BATCH_SIZE, shuffle=False)
    model = BaselineCNN(num_classes=len(classes)).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    all_labels = []
    all_predictions = []
    top3_scores = []

    with torch.no_grad():
        for images, labels in dataloader:
            images = images.to(device)
            labels = labels.to(device)
            outputs = model(images)
            _, predicted = outputs.max(1)

            all_labels.extend(labels.cpu().tolist())
            all_predictions.extend(predicted.cpu().tolist())
            top3_scores.append(compute_top_k_accuracy(outputs, labels, k=min(3, len(classes))))

    precision, recall, f1, _ = precision_recall_fscore_support(
        all_labels,
        all_predictions,
        average="weighted",
        zero_division=0,
    )
    accuracy = accuracy_score(all_labels, all_predictions)
    matrix = confusion_matrix(all_labels, all_predictions, labels=list(range(len(classes))))

    metrics = {
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1_score": f1,
        "top_3_accuracy": sum(top3_scores) / max(len(top3_scores), 1),
    }

    save_json(metrics, REPORTS_OUTPUT_PATH / "metrics.json")
    save_confusion_matrix_csv(matrix, classes, REPORTS_OUTPUT_PATH / "confusion_matrix.csv")
    save_confusion_matrix_plot(matrix, classes, REPORTS_OUTPUT_PATH / "confusion_matrix.png")

    report = classification_report(
        all_labels,
        all_predictions,
        target_names=classes,
        output_dict=True,
        zero_division=0,
    )
    with open(REPORTS_OUTPUT_PATH / "classification_report.csv", "w", newline="", encoding="utf-8") as csv_file:
        fieldnames = ["class", "precision", "recall", "f1-score", "support"]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for class_name, values in report.items():
            if isinstance(values, dict):
                writer.writerow({"class": class_name, **values})

    print(f"Metrics saved to: {REPORTS_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
