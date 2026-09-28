from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
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
    from .experiment_artifacts import (
        DEFAULT_DATASET_ROOT,
        RUNTIME_IMAGE_SIZE,
        assert_staging_run_path,
        assert_path_outside_dataset,
        dataset_fingerprint,
        file_sha256,
        load_class_order,
        load_json_object,
        require_completed_training_run,
        require_same_dataset_fingerprint,
        require_same_class_order,
        timestamped_run_dir,
        validate_checkpoint_class_order,
        validate_checkpoint_image_size,
        validate_dataset_class_order,
        write_json,
    )
    from .train_efficientnet_transfer import build_model, build_transforms, get_device
except ImportError:
    from experiment_artifacts import (
        DEFAULT_DATASET_ROOT,
        RUNTIME_IMAGE_SIZE,
        assert_staging_run_path,
        assert_path_outside_dataset,
        dataset_fingerprint,
        file_sha256,
        load_class_order,
        load_json_object,
        require_completed_training_run,
        require_same_dataset_fingerprint,
        require_same_class_order,
        timestamped_run_dir,
        validate_checkpoint_class_order,
        validate_checkpoint_image_size,
        validate_dataset_class_order,
        write_json,
    )
    from train_efficientnet_transfer import build_model, build_transforms, get_device


def save_confusion_matrix_plot(matrix, classes: list[str], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
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
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        fieldnames = ["class", "precision", "recall", "f1-score", "support"]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for class_name, values in report.items():
            if isinstance(values, dict):
                writer.writerow({"class": class_name, **values})


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Evaluate a completed staged EfficientNet training run. Evaluation reports are "
            "written to a separate timestamped staging directory by default."
        )
    )
    parser.add_argument(
        "--source-run-dir",
        type=Path,
        required=True,
        help="Completed training run containing checkpoints/, class_order.json, and RUN_COMPLETE.json.",
    )
    parser.add_argument(
        "--dataset-root",
        type=Path,
        default=DEFAULT_DATASET_ROOT,
        help="Dataset root containing the held-out test/ directory.",
    )
    parser.add_argument(
        "--run-dir",
        type=Path,
        help=(
            "New, empty evaluation output directory. When omitted, a timestamped directory "
            "is created under <source-run-dir>/evaluations/."
        ),
    )
    parser.add_argument(
        "--expected-class-order",
        type=Path,
        help="Optional additional class-order contract to enforce for the test dataset.",
    )
    parser.add_argument(
        "--allow-legacy-dataset",
        action="store_true",
        help=(
            "Explicitly allow evaluation of an eligible legacy training dataset. "
            "This is forbidden for the 29-class or unknown-class workflow."
        ),
    )
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--num-workers", type=int, default=0)
    return parser


def _initialize_evaluation_run(run_dir: Path) -> tuple[Path, Path]:
    output = assert_staging_run_path(run_dir)
    if output.exists() and any(output.iterdir()):
        raise FileExistsError(f"Refusing to overwrite non-empty evaluation run: {output}")
    reports = output / "reports"
    reports.mkdir(parents=True, exist_ok=True)
    incomplete = output / "RUN_INCOMPLETE"
    incomplete.write_text(
        "Evaluation has not completed. Do not use these reports for promotion.\n",
        encoding="utf-8",
    )
    return output, reports


def main() -> None:
    args = build_argument_parser().parse_args()
    if args.batch_size < 1:
        raise ValueError("--batch-size must be at least 1.")
    if args.num_workers < 0:
        raise ValueError("--num-workers cannot be negative.")

    source = require_completed_training_run(args.source_run_dir)
    dataset_root = args.dataset_root.expanduser().resolve()
    classes = load_class_order(source.class_order)
    training_marker = load_json_object(
        source.complete_marker,
        description="training completion marker",
    )
    recorded_dataset_root = Path(str(training_marker["dataset_root"])).expanduser().resolve()
    if dataset_root != recorded_dataset_root:
        raise ValueError(
            "Evaluation must use the exact staged dataset recorded by training: "
            f"expected={recorded_dataset_root}, received={dataset_root}."
        )
    recorded_contract = training_marker.get("dataset_contract")
    if recorded_contract == "legacy_explicit" and not args.allow_legacy_dataset:
        raise ValueError(
            "This training run used a legacy dataset. Pass --allow-legacy-dataset "
            "explicitly to evaluate it."
        )
    if recorded_contract not in {"staged_builder_v1", "legacy_explicit"}:
        raise ValueError("Training completion marker has no supported dataset_contract.")
    recorded_dataset_fingerprint = training_marker["dataset_fingerprint"]
    evaluation_start_fingerprint = dataset_fingerprint(dataset_root)
    require_same_dataset_fingerprint(
        recorded_dataset_fingerprint,
        evaluation_start_fingerprint,
        expected_name="completed training run",
        actual_name="dataset at evaluation start",
    )

    test_classes = validate_dataset_class_order(
        dataset_root,
        splits=("test",),
        expected_class_order_path=args.expected_class_order,
        allow_legacy_dataset=args.allow_legacy_dataset,
    )
    require_same_class_order(
        classes,
        test_classes,
        expected_name=str(source.class_order),
        actual_name=f"test folder order under {dataset_root}",
    )

    output_run = args.run_dir or timestamped_run_dir(
        source.run_dir / "evaluations", prefix="evaluation"
    )
    output_run = assert_path_outside_dataset(
        output_run,
        dataset_root,
        label="Evaluation output directory",
    )
    output_run, report_dir = _initialize_evaluation_run(output_run)
    write_json(classes, output_run / "class_order.json")

    checkpoint = torch.load(source.checkpoint, map_location="cpu")
    validate_checkpoint_class_order(checkpoint, classes)
    image_size = validate_checkpoint_image_size(checkpoint)
    if "model_state_dict" not in checkpoint:
        raise ValueError("Checkpoint does not contain model_state_dict.")
    _, test_transform = build_transforms(image_size)

    dataset = datasets.ImageFolder(dataset_root / "test", transform=test_transform)
    if dataset.classes != classes:
        raise RuntimeError(
            "Test class folder order changed after validation. Rebuild the versioned dataset "
            "before evaluating."
        )

    dataloader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
    )
    device = get_device()
    model = build_model(
        checkpoint.get("model_name", "efficientnet_b0"),
        len(classes),
        pretrained=False,
    ).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    all_labels: list[int] = []
    all_predictions: list[int] = []

    with torch.no_grad():
        for images, labels in dataloader:
            images = images.to(device)
            labels = labels.to(device)
            outputs = model(images)
            if outputs.ndim != 2 or outputs.shape[1] != len(classes):
                raise RuntimeError(
                    "Model output count does not match class_order.json: "
                    f"output_shape={tuple(outputs.shape)}, class_count={len(classes)}."
                )
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

    confusion_matrix_path = report_dir / "confusion_matrix.png"
    classification_report_path = report_dir / "classification_report.csv"
    test_metrics_path = report_dir / "test_metrics.json"

    matrix = confusion_matrix(all_labels, all_predictions, labels=list(range(len(classes))))
    save_confusion_matrix_plot(matrix, classes, confusion_matrix_path)

    report = classification_report(
        all_labels,
        all_predictions,
        labels=list(range(len(classes))),
        target_names=classes,
        output_dict=True,
        zero_division=0,
    )
    save_classification_report_csv(report, classification_report_path)

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
    write_json(metrics, test_metrics_path)

    evaluation_end_fingerprint = dataset_fingerprint(dataset_root)
    require_same_dataset_fingerprint(
        evaluation_start_fingerprint,
        evaluation_end_fingerprint,
        expected_name="dataset at evaluation start",
        actual_name="dataset at evaluation completion",
    )

    evaluation_class_order_path = output_run / "class_order.json"
    evaluation_artifacts = {
        "class_order.json": file_sha256(evaluation_class_order_path),
        "reports/test_metrics.json": file_sha256(test_metrics_path),
        "reports/classification_report.csv": file_sha256(classification_report_path),
        "reports/confusion_matrix.png": file_sha256(confusion_matrix_path),
    }

    manifest = {
        "schema_version": 1,
        "status": "complete",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "source_training_run": str(source.run_dir),
        "checkpoint": str(source.checkpoint),
        "checkpoint_sha256": file_sha256(source.checkpoint),
        "class_order_sha256": file_sha256(source.class_order),
        "dataset_root": str(dataset_root),
        "dataset_contract": recorded_contract,
        "dataset_fingerprint": evaluation_end_fingerprint,
        "class_count": len(classes),
        "class_order": classes,
        "image_size": RUNTIME_IMAGE_SIZE,
        "test_metrics": str(test_metrics_path),
        "evaluation_artifact_sha256": evaluation_artifacts,
    }
    write_json(manifest, output_run / "run_manifest.json")
    (output_run / "RUN_INCOMPLETE").unlink(missing_ok=True)
    write_json(manifest, output_run / "RUN_COMPLETE.json")

    print(f"Evaluation run: {output_run}")
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
