from __future__ import annotations

import argparse
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

try:
    from .experiment_artifacts import (
        ACTIVE_SERVER_MODEL_DIR,
        ExperimentConfigurationError,
        RUNTIME_IMAGE_SIZE,
        assert_path_outside_dataset,
        assert_staging_run_path,
        file_sha256,
        load_class_order,
        load_json_object,
        promote_checkpoint_bundle,
        require_completed_training_run,
        require_same_dataset_fingerprint,
        require_same_class_order,
        verify_dataset_fingerprint,
        validate_checkpoint_class_order,
        validate_checkpoint_image_size,
        write_json,
    )
except ImportError:
    from experiment_artifacts import (
        ACTIVE_SERVER_MODEL_DIR,
        ExperimentConfigurationError,
        RUNTIME_IMAGE_SIZE,
        assert_path_outside_dataset,
        assert_staging_run_path,
        file_sha256,
        load_class_order,
        load_json_object,
        promote_checkpoint_bundle,
        require_completed_training_run,
        require_same_dataset_fingerprint,
        require_same_class_order,
        verify_dataset_fingerprint,
        validate_checkpoint_class_order,
        validate_checkpoint_image_size,
        write_json,
    )


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Explicitly promote an evaluated EfficientNet checkpoint and class-order pair "
            "to the active Python service. Nothing is promoted by default."
        )
    )
    parser.add_argument("--source-run-dir", type=Path, required=True)
    parser.add_argument("--evaluation-run-dir", type=Path, required=True)
    parser.add_argument("--min-accuracy", type=float, required=True)
    parser.add_argument("--min-macro-f1", type=float, required=True)
    parser.add_argument("--min-per-class-precision", type=float, required=True)
    parser.add_argument("--min-per-class-recall", type=float, required=True)
    parser.add_argument("--min-per-class-f1", type=float, required=True)
    parser.add_argument("--min-per-class-support", type=int, required=True)
    parser.add_argument(
        "--promote",
        action="store_true",
        required=True,
        help="Required acknowledgement that the validated bundle should replace active files.",
    )
    parser.add_argument(
        "--destination-dir",
        type=Path,
        default=ACTIVE_SERVER_MODEL_DIR,
        help=argparse.SUPPRESS,
    )
    return parser


def _as_probability(value: float, name: str) -> float:
    if not math.isfinite(value) or value < 0 or value > 1:
        raise ExperimentConfigurationError(f"{name} must be a finite value from 0 to 1.")
    return value


def validate_evaluation_thresholds(
    metrics: dict,
    classes: Sequence[str],
    *,
    minimum_accuracy: float,
    minimum_macro_f1: float,
    minimum_per_class_precision: float,
    minimum_per_class_recall: float,
    minimum_per_class_f1: float,
    minimum_per_class_support: int,
) -> dict[str, float | int]:
    if isinstance(minimum_per_class_support, bool) or minimum_per_class_support < 1:
        raise ExperimentConfigurationError("--min-per-class-support must be at least 1.")
    thresholds = {
        "accuracy": _as_probability(minimum_accuracy, "--min-accuracy"),
        "macro_f1": _as_probability(minimum_macro_f1, "--min-macro-f1"),
        "minimum_per_class_precision": _as_probability(
            minimum_per_class_precision,
            "--min-per-class-precision",
        ),
        "minimum_per_class_recall": _as_probability(
            minimum_per_class_recall,
            "--min-per-class-recall",
        ),
        "minimum_per_class_f1": _as_probability(
            minimum_per_class_f1,
            "--min-per-class-f1",
        ),
        "minimum_per_class_support": minimum_per_class_support,
    }
    metric_classes = metrics.get("classes")
    if not isinstance(metric_classes, list):
        raise ExperimentConfigurationError("Evaluation metrics have no classes list.")
    require_same_class_order(
        classes,
        metric_classes,
        expected_name="training class_order.json",
        actual_name="evaluation metrics classes",
    )

    try:
        accuracy = float(metrics["accuracy"])
        macro_f1 = float(metrics["macro_f1"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ExperimentConfigurationError(
            "Evaluation metrics must contain numeric accuracy and macro_f1 values."
        ) from exc
    accuracy = _as_probability(accuracy, "evaluation accuracy")
    macro_f1 = _as_probability(macro_f1, "evaluation macro_f1")

    per_class = metrics.get("per_class")
    if not isinstance(per_class, list) or len(per_class) != len(classes):
        raise ExperimentConfigurationError(
            "Evaluation metrics must contain one per_class row for every class."
        )
    precisions: list[float] = []
    recalls: list[float] = []
    f1_scores: list[float] = []
    supports: list[int] = []
    for expected_class, row in zip(classes, per_class):
        if not isinstance(row, dict) or row.get("class") != expected_class:
            raise ExperimentConfigurationError(
                "Evaluation per_class rows do not match the training class order."
            )
        try:
            precision = float(row["precision"])
            recall = float(row["recall"])
            f1_score = float(row["f1"])
            support_value = row["support"]
            if isinstance(support_value, bool):
                raise ValueError
            support = int(support_value)
            if float(support_value) != support:
                raise ValueError
        except (KeyError, TypeError, ValueError) as exc:
            raise ExperimentConfigurationError(
                f"Evaluation precision, recall, F1, or support is missing or invalid for {expected_class}."
            ) from exc
        if support < 0:
            raise ExperimentConfigurationError(
                f"Evaluation support cannot be negative for {expected_class}."
            )
        precisions.append(
            _as_probability(precision, f"evaluation precision for {expected_class}")
        )
        recalls.append(_as_probability(recall, f"evaluation recall for {expected_class}"))
        f1_scores.append(_as_probability(f1_score, f"evaluation F1 for {expected_class}"))
        supports.append(support)

    observed = {
        "accuracy": accuracy,
        "macro_f1": macro_f1,
        "minimum_per_class_precision": min(precisions),
        "minimum_per_class_recall": min(recalls),
        "minimum_per_class_f1": min(f1_scores),
        "minimum_per_class_support": min(supports),
    }
    failures = [
        f"{name}={observed[name]:.6f} is below required {threshold:.6f}"
        for name, threshold in thresholds.items()
        if observed[name] < threshold
    ]
    if failures:
        raise ExperimentConfigurationError(
            "Evaluation thresholds were not met: " + "; ".join(failures)
        )
    return observed


def _resolved_recorded_path(value: object, field: str) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise ExperimentConfigurationError(f"Run manifest is missing {field}.")
    return Path(value).expanduser().resolve()


def validate_evaluation_run(
    *,
    training_run_dir: Path,
    evaluation_run_dir: Path,
    classes: Sequence[str],
) -> tuple[dict, dict, Path]:
    training_run = Path(training_run_dir).expanduser().resolve()
    evaluation_run = assert_staging_run_path(evaluation_run_dir)
    incomplete = evaluation_run / "RUN_INCOMPLETE"
    complete = evaluation_run / "RUN_COMPLETE.json"
    metrics_path = evaluation_run / "reports" / "test_metrics.json"
    evaluation_class_order_path = evaluation_run / "class_order.json"
    classification_report_path = evaluation_run / "reports" / "classification_report.csv"
    confusion_matrix_path = evaluation_run / "reports" / "confusion_matrix.png"
    missing = [
        path
        for path in (
            complete,
            metrics_path,
            evaluation_class_order_path,
            classification_report_path,
            confusion_matrix_path,
        )
        if not path.is_file()
    ]
    if incomplete.exists() or missing:
        details = ", ".join(str(path) for path in missing) or str(incomplete)
        raise ExperimentConfigurationError(
            f"Evaluation run is incomplete or missing required artifacts: {details}"
        )

    training_manifest = load_json_object(
        training_run / "RUN_COMPLETE.json",
        description="training completion marker",
    )
    evaluation_marker = load_json_object(complete, description="evaluation completion marker")
    if evaluation_marker.get("status") != "complete":
        raise ExperimentConfigurationError(
            f"Evaluation completion marker does not have status=complete: {complete}"
        )
    recorded_source = _resolved_recorded_path(
        evaluation_marker.get("source_training_run"),
        "source_training_run",
    )
    if recorded_source != training_run:
        raise ExperimentConfigurationError(
            "Evaluation run belongs to a different training run: "
            f"expected={training_run}, recorded={recorded_source}."
        )

    recorded_metrics = _resolved_recorded_path(
        evaluation_marker.get("test_metrics"),
        "evaluation test_metrics",
    )
    if recorded_metrics != metrics_path.resolve():
        raise ExperimentConfigurationError(
            "Evaluation completion marker points to an unexpected metrics file: "
            f"expected={metrics_path.resolve()}, recorded={recorded_metrics}."
        )

    training_dataset = _resolved_recorded_path(
        training_manifest.get("dataset_root"),
        "training dataset_root",
    )
    evaluation_dataset = _resolved_recorded_path(
        evaluation_marker.get("dataset_root"),
        "evaluation dataset_root",
    )
    if training_dataset != evaluation_dataset:
        raise ExperimentConfigurationError(
            "Training and evaluation used different dataset versions: "
            f"training={training_dataset}, evaluation={evaluation_dataset}."
        )
    assert_path_outside_dataset(
        training_run,
        training_dataset,
        label="Training run directory",
    )
    assert_path_outside_dataset(
        evaluation_run,
        training_dataset,
        label="Evaluation run directory",
    )
    training_contract = training_manifest.get("dataset_contract")
    if training_contract not in {"staged_builder_v1", "legacy_explicit"}:
        raise ExperimentConfigurationError(
            "Training completion marker has no supported dataset_contract."
        )
    if evaluation_marker.get("dataset_contract") != training_contract:
        raise ExperimentConfigurationError(
            "Evaluation dataset_contract differs from the training run."
        )

    training_fingerprint = training_manifest.get("dataset_fingerprint")
    evaluation_fingerprint = evaluation_marker.get("dataset_fingerprint")
    require_same_dataset_fingerprint(
        training_fingerprint,
        evaluation_fingerprint,
        expected_name="training run manifest",
        actual_name="evaluation completion marker",
    )
    verify_dataset_fingerprint(training_dataset, training_fingerprint)

    if evaluation_marker.get("image_size") != RUNTIME_IMAGE_SIZE:
        raise ExperimentConfigurationError(
            "Evaluation image size is incompatible with runtime preprocessing: "
            f"expected={RUNTIME_IMAGE_SIZE}, recorded={evaluation_marker.get('image_size')!r}."
        )

    evaluation_classes = load_class_order(evaluation_class_order_path)
    require_same_class_order(
        classes,
        evaluation_classes,
        expected_name="training class_order.json",
        actual_name="evaluation class_order.json",
    )
    marker_classes = evaluation_marker.get("class_order")
    if not isinstance(marker_classes, list):
        raise ExperimentConfigurationError("Evaluation completion marker has no class_order list.")
    require_same_class_order(
        classes,
        marker_classes,
        expected_name="training class_order.json",
        actual_name="evaluation completion marker",
    )
    training_checkpoint = training_run / "checkpoints" / "efficientnet_b0_best.pth"
    training_class_order = training_run / "class_order.json"
    for field, artifact in (
        ("checkpoint_sha256", training_checkpoint),
        ("class_order_sha256", training_class_order),
    ):
        recorded_hash = evaluation_marker.get(field)
        if not isinstance(recorded_hash, str) or len(recorded_hash) != 64:
            raise ExperimentConfigurationError(
                f"Evaluation completion marker has no valid {field}."
            )
        if file_sha256(artifact) != recorded_hash.lower():
            raise ExperimentConfigurationError(
                f"Training artifact no longer matches the evaluated version: {artifact}"
            )

    expected_evaluation_artifacts = {
        "class_order.json": evaluation_class_order_path,
        "reports/test_metrics.json": metrics_path,
        "reports/classification_report.csv": classification_report_path,
        "reports/confusion_matrix.png": confusion_matrix_path,
    }
    recorded_artifact_hashes = evaluation_marker.get("evaluation_artifact_sha256")
    if not isinstance(recorded_artifact_hashes, dict):
        raise ExperimentConfigurationError(
            "Evaluation completion marker has no evaluation_artifact_sha256 object."
        )
    if set(recorded_artifact_hashes) != set(expected_evaluation_artifacts):
        raise ExperimentConfigurationError(
            "Evaluation completion marker does not hash the exact required report artifacts."
        )
    for artifact_name, artifact_path in expected_evaluation_artifacts.items():
        expected_hash = recorded_artifact_hashes.get(artifact_name)
        if not isinstance(expected_hash, str) or len(expected_hash) != 64:
            raise ExperimentConfigurationError(
                f"Evaluation completion marker has no valid hash for {artifact_name}."
            )
        if file_sha256(artifact_path) != expected_hash.lower():
            raise ExperimentConfigurationError(
                f"Evaluated artifact changed after completion: {artifact_path}"
            )
    metrics = load_json_object(metrics_path, description="evaluation test metrics")
    return training_manifest, metrics, training_dataset


def main() -> None:
    args = build_argument_parser().parse_args()
    source = require_completed_training_run(args.source_run_dir)
    classes = load_class_order(source.class_order)
    training_manifest, metrics, dataset_root = validate_evaluation_run(
        training_run_dir=source.run_dir,
        evaluation_run_dir=args.evaluation_run_dir,
        classes=classes,
    )
    observed = validate_evaluation_thresholds(
        metrics,
        classes,
        minimum_accuracy=args.min_accuracy,
        minimum_macro_f1=args.min_macro_f1,
        minimum_per_class_precision=args.min_per_class_precision,
        minimum_per_class_recall=args.min_per_class_recall,
        minimum_per_class_f1=args.min_per_class_f1,
        minimum_per_class_support=args.min_per_class_support,
    )

    import torch

    expected_checkpoint_hash = training_manifest.get("checkpoint_sha256")
    expected_class_order_hash = training_manifest.get("class_order_sha256")
    if file_sha256(source.checkpoint) != expected_checkpoint_hash:
        raise ExperimentConfigurationError("Training checkpoint changed before promotion load.")
    if file_sha256(source.class_order) != expected_class_order_hash:
        raise ExperimentConfigurationError("Training class order changed before promotion load.")
    checkpoint = torch.load(source.checkpoint, map_location="cpu")
    if file_sha256(source.checkpoint) != expected_checkpoint_hash:
        raise ExperimentConfigurationError("Training checkpoint changed while it was loaded.")
    if file_sha256(source.class_order) != expected_class_order_hash:
        raise ExperimentConfigurationError("Training class order changed during promotion validation.")
    validate_checkpoint_class_order(checkpoint, classes)
    validate_checkpoint_image_size(checkpoint)
    destination_dir = assert_path_outside_dataset(
        args.destination_dir,
        dataset_root,
        label="Server model destination",
    )
    assert_path_outside_dataset(
        destination_dir,
        source.run_dir,
        label="Server model destination relative to the training run",
    )
    assert_path_outside_dataset(
        destination_dir,
        Path(args.evaluation_run_dir).expanduser().resolve(),
        label="Server model destination relative to the evaluation run",
    )
    receipt_path = (
        source.run_dir
        / "promotions"
        / f"server-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')}.json"
    )
    checkpoint_target = destination_dir / "efficientnet_b0_best.pth"
    class_order_target = destination_dir / "class_order.json"
    receipt = {
        "schema_version": 1,
        "status": "promotion_planned",
        "planned_at": datetime.now(timezone.utc).isoformat(),
        "source_training_run": str(source.run_dir),
        "evaluation_run": str(Path(args.evaluation_run_dir).expanduser().resolve()),
        "dataset_root": str(dataset_root),
        "dataset_fingerprint": training_manifest["dataset_fingerprint"],
        "class_count": len(classes),
        "image_size": RUNTIME_IMAGE_SIZE,
        "thresholds": {
            "minimum_accuracy": args.min_accuracy,
            "minimum_macro_f1": args.min_macro_f1,
            "minimum_per_class_precision": args.min_per_class_precision,
            "minimum_per_class_recall": args.min_per_class_recall,
            "minimum_per_class_f1": args.min_per_class_f1,
            "minimum_per_class_support": args.min_per_class_support,
        },
        "observed": observed,
        "active_checkpoint": str(checkpoint_target),
        "active_class_order": str(class_order_target),
        "checkpoint_sha256": expected_checkpoint_hash,
        "class_order_sha256": expected_class_order_hash,
    }
    # Persist a recoverable plan before mutating the active pair. If this write fails,
    # promotion has not started.
    write_json(receipt, receipt_path)
    checkpoint_target, class_order_target = promote_checkpoint_bundle(
        source_checkpoint=source.checkpoint,
        source_class_order=source.class_order,
        destination_dir=destination_dir,
        expected_checkpoint_sha256=receipt["checkpoint_sha256"],
        expected_class_order_sha256=receipt["class_order_sha256"],
    )
    receipt["status"] = "complete"
    receipt["promoted_at"] = datetime.now(timezone.utc).isoformat()
    receipt_warning = None
    try:
        write_json(receipt, receipt_path)
    except OSError as exc:
        receipt_warning = (
            "Active server artifacts were installed and hash-verified, but the promotion "
            f"receipt could not be finalized: {exc}"
        )

    print("Server EfficientNet bundle promoted")
    print(f"checkpoint: {checkpoint_target}")
    print(f"class order: {class_order_target}")
    print(f"receipt: {receipt_path}")
    if receipt_warning:
        print(f"WARNING: {receipt_warning}")


if __name__ == "__main__":
    main()
