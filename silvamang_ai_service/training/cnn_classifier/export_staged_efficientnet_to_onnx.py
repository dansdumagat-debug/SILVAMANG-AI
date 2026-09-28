from __future__ import annotations

import argparse
import inspect
from datetime import datetime, timezone
from pathlib import Path

try:
    from .experiment_artifacts import (
        ACTIVE_FLUTTER_MODEL_DIR,
        ExperimentConfigurationError,
        PREFERRED_FLUTTER_MODEL_FILENAME,
        RUNTIME_IMAGE_SIZE,
        assert_path_outside_dataset,
        assert_staging_run_path,
        file_sha256,
        load_class_order,
        load_json_object,
        promote_onnx_bundle,
        require_completed_training_run,
        validate_checkpoint_class_order,
        validate_checkpoint_image_size,
        write_json,
    )
    from .promote_efficientnet_run import (
        validate_evaluation_run,
        validate_evaluation_thresholds,
    )
except ImportError:
    from experiment_artifacts import (
        ACTIVE_FLUTTER_MODEL_DIR,
        ExperimentConfigurationError,
        PREFERRED_FLUTTER_MODEL_FILENAME,
        RUNTIME_IMAGE_SIZE,
        assert_path_outside_dataset,
        assert_staging_run_path,
        file_sha256,
        load_class_order,
        load_json_object,
        promote_onnx_bundle,
        require_completed_training_run,
        validate_checkpoint_class_order,
        validate_checkpoint_image_size,
        write_json,
    )
    from promote_efficientnet_run import (
        validate_evaluation_run,
        validate_evaluation_thresholds,
    )


DEFAULT_MODEL_FILENAME = PREFERRED_FLUTTER_MODEL_FILENAME


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Export a completed staged EfficientNet run to ONNX. By default the ONNX model "
            "and matching class order remain inside the experiment run."
        )
    )
    parser.add_argument(
        "--source-run-dir",
        type=Path,
        required=True,
        help="Completed training run containing the checkpoint and matching class_order.json.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="New, empty staging export directory. Defaults to <source-run-dir>/exports.",
    )
    parser.add_argument("--opset", type=int, default=14)
    parser.add_argument(
        "--promote-to-flutter",
        action="store_true",
        help=(
            "Explicitly replace the Flutter ONNX model and class_order.json with the staged "
            "pair after export validation. Omit this flag for experiment-only exports."
        ),
    )
    parser.add_argument(
        "--flutter-assets-dir",
        type=Path,
        default=ACTIVE_FLUTTER_MODEL_DIR,
        help=argparse.SUPPRESS,
    )
    parser.add_argument("--evaluation-run-dir", type=Path)
    parser.add_argument("--min-accuracy", type=float)
    parser.add_argument("--min-macro-f1", type=float)
    parser.add_argument("--min-per-class-precision", type=float)
    parser.add_argument("--min-per-class-recall", type=float)
    parser.add_argument("--min-per-class-f1", type=float)
    parser.add_argument("--min-per-class-support", type=int)
    return parser


def _validate_single_file_onnx(model_path: Path, class_count: int) -> None:
    import onnx
    from onnx.external_data_helper import uses_external_data

    model = onnx.load(str(model_path), load_external_data=False)
    onnx.checker.check_model(model)
    external_tensors = [tensor.name for tensor in model.graph.initializer if uses_external_data(tensor)]
    if external_tensors:
        raise RuntimeError(
            "Exported ONNX model still references external tensor data. "
            f"Single-file Flutter asset required; tensors={external_tensors[:5]}."
        )
    if not model.graph.input:
        raise RuntimeError("Exported ONNX graph has no input tensor.")
    input_shape = model.graph.input[0].type.tensor_type.shape.dim
    input_dimensions = [
        dimension.dim_value if dimension.HasField("dim_value") else None
        for dimension in input_shape
    ]
    expected_input = [1, 3, RUNTIME_IMAGE_SIZE, RUNTIME_IMAGE_SIZE]
    if input_dimensions != expected_input:
        raise RuntimeError(
            "Exported ONNX input shape is incompatible with Flutter preprocessing: "
            f"expected={expected_input}, actual={input_dimensions}."
        )
    if not model.graph.output:
        raise RuntimeError("Exported ONNX graph has no output tensor.")
    shape = model.graph.output[0].type.tensor_type.shape.dim
    output_dimensions = [
        dimension.dim_value if dimension.HasField("dim_value") else None
        for dimension in shape
    ]
    expected_output = [1, class_count]
    if output_dimensions != expected_output:
        raise RuntimeError(
            "Exported ONNX output shape does not match class_order.json: "
            f"expected={expected_output}, actual={output_dimensions}."
        )


def _require_flutter_promotion_gate(args, source, classes: list[str]) -> tuple[dict, dict]:
    required = {
        "--evaluation-run-dir": args.evaluation_run_dir,
        "--min-accuracy": args.min_accuracy,
        "--min-macro-f1": args.min_macro_f1,
        "--min-per-class-precision": args.min_per_class_precision,
        "--min-per-class-recall": args.min_per_class_recall,
        "--min-per-class-f1": args.min_per_class_f1,
        "--min-per-class-support": args.min_per_class_support,
    }
    missing = [name for name, value in required.items() if value is None]
    if missing:
        raise ExperimentConfigurationError(
            "Flutter promotion requires a completed evaluation and every explicit acceptance "
            f"threshold. Missing: {', '.join(missing)}."
        )
    _, metrics, _ = validate_evaluation_run(
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
    return metrics, observed


def main() -> None:
    args = build_argument_parser().parse_args()
    if args.opset < 12:
        raise ValueError("--opset must be 12 or newer.")

    source = require_completed_training_run(args.source_run_dir)
    classes = load_class_order(source.class_order)
    promotion_observed = None
    if args.promote_to_flutter:
        _, promotion_observed = _require_flutter_promotion_gate(args, source, classes)
    training_marker = load_json_object(
        source.complete_marker,
        description="training completion marker",
    )
    expected_checkpoint_hash = training_marker["checkpoint_sha256"]
    expected_class_order_hash = training_marker["class_order_sha256"]
    dataset_root = Path(str(training_marker["dataset_root"])).expanduser().resolve()
    output_dir = assert_path_outside_dataset(
        assert_staging_run_path(args.output_dir or source.exports_dir),
        dataset_root,
        label="ONNX export directory",
    )
    flutter_assets_dir = args.flutter_assets_dir
    if args.promote_to_flutter:
        flutter_assets_dir = assert_path_outside_dataset(
            args.flutter_assets_dir,
            dataset_root,
            label="Flutter model destination",
        )
        assert_path_outside_dataset(
            flutter_assets_dir,
            source.run_dir,
            label="Flutter model destination relative to the training run",
        )
        if args.evaluation_run_dir is not None:
            assert_path_outside_dataset(
                flutter_assets_dir,
                args.evaluation_run_dir,
                label="Flutter model destination relative to the evaluation run",
            )
        if (
            flutter_assets_dir == output_dir
            or output_dir in flutter_assets_dir.parents
            or flutter_assets_dir in output_dir.parents
        ):
            raise ExperimentConfigurationError(
                "Flutter model destination cannot contain the staged ONNX export directory."
            )
    if output_dir.exists() and any(output_dir.iterdir()):
        raise FileExistsError(f"Refusing to overwrite non-empty staged export: {output_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)
    incomplete = output_dir / "EXPORT_INCOMPLETE"
    incomplete.write_text(
        "ONNX export has not completed. Do not promote this bundle.\n",
        encoding="utf-8",
    )

    import torch
    from torchvision import models

    if file_sha256(source.checkpoint) != expected_checkpoint_hash:
        raise ExperimentConfigurationError("Training checkpoint changed before ONNX export load.")
    if file_sha256(source.class_order) != expected_class_order_hash:
        raise ExperimentConfigurationError("Training class order changed before ONNX export.")
    checkpoint = torch.load(source.checkpoint, map_location="cpu")
    if file_sha256(source.checkpoint) != expected_checkpoint_hash:
        raise ExperimentConfigurationError("Training checkpoint changed while it was loaded.")
    validate_checkpoint_class_order(checkpoint, classes)
    image_size = validate_checkpoint_image_size(checkpoint)
    state_dict = checkpoint.get("model_state_dict")
    if not isinstance(state_dict, dict):
        raise ValueError("Checkpoint does not contain model_state_dict.")
    model_name = checkpoint.get("model_name", "efficientnet_b0")
    if model_name != "efficientnet_b0":
        raise ValueError(f"Unsupported model for this exporter: {model_name}")

    model = models.efficientnet_b0(weights=None)
    in_features = model.classifier[1].in_features
    model.classifier[1] = torch.nn.Linear(in_features, len(classes))
    model.load_state_dict(state_dict)
    model.eval()

    dummy_input = torch.randn(1, 3, image_size, image_size)
    with torch.no_grad():
        output = model(dummy_input)
    if output.ndim != 2 or output.shape[1] != len(classes):
        raise RuntimeError(
            "PyTorch model output count does not match class_order.json: "
            f"output_shape={tuple(output.shape)}, class_count={len(classes)}."
        )

    output_path = output_dir / DEFAULT_MODEL_FILENAME
    temporary_path = output_dir / f".{DEFAULT_MODEL_FILENAME}.tmp.onnx"
    export_options = {
        "export_params": True,
        "opset_version": args.opset,
        "do_constant_folding": True,
        "input_names": ["input"],
        "output_names": ["output"],
        "dynamic_axes": None,
    }
    export_parameters = inspect.signature(torch.onnx.export).parameters
    if "dynamo" in export_parameters:
        export_options["dynamo"] = False
    if "external_data" in export_parameters:
        export_options["external_data"] = False
    torch.onnx.export(
        model,
        dummy_input,
        temporary_path,
        **export_options,
    )
    _validate_single_file_onnx(temporary_path, len(classes))
    temporary_path.replace(output_path)

    exported_class_order = output_dir / "class_order.json"
    write_json(classes, exported_class_order)
    manifest = {
        "schema_version": 1,
        "status": "complete",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "source_training_run": str(source.run_dir),
        "source_checkpoint": str(source.checkpoint),
        "source_checkpoint_sha256": expected_checkpoint_hash,
        "source_class_order_sha256": expected_class_order_hash,
        "model": str(output_path),
        "class_order": str(exported_class_order),
        "model_sha256": file_sha256(output_path),
        "class_order_sha256": file_sha256(exported_class_order),
        "class_count": len(classes),
        "image_size": image_size,
        "opset": args.opset,
        "promotion_status": (
            "promotion_planned" if args.promote_to_flutter else "not_requested"
        ),
    }
    if args.promote_to_flutter:
        manifest["evaluation_run"] = str(args.evaluation_run_dir.expanduser().resolve())
        manifest["acceptance_thresholds"] = {
            "minimum_accuracy": args.min_accuracy,
            "minimum_macro_f1": args.min_macro_f1,
            "minimum_per_class_precision": args.min_per_class_precision,
            "minimum_per_class_recall": args.min_per_class_recall,
            "minimum_per_class_f1": args.min_per_class_f1,
            "minimum_per_class_support": args.min_per_class_support,
        }
        manifest["observed"] = promotion_observed
    write_json(manifest, output_dir / "export_manifest.json")
    incomplete_cleanup_error = None
    try:
        incomplete.unlink(missing_ok=True)
    except Exception as exc:
        incomplete_cleanup_error = exc
        manifest["status"] = "incomplete_marker_cleanup_failed"
        try:
            write_json(manifest, output_dir / "export_manifest.json")
        except Exception:
            pass
        print(
            "WARNING: ONNX files were exported, but the bundle is not qualified because its "
            "incomplete marker could not be "
            f"removed: {exc}"
        )

    if args.promote_to_flutter:
        if incomplete_cleanup_error is not None:
            raise ExperimentConfigurationError(
                "Flutter promotion is blocked because EXPORT_INCOMPLETE could not be removed."
            ) from incomplete_cleanup_error
        # Re-run the complete gate immediately before mutation so an artifact or dataset
        # changed during export cannot be promoted.
        source = require_completed_training_run(args.source_run_dir)
        _require_flutter_promotion_gate(args, source, classes)
        if file_sha256(source.checkpoint) != expected_checkpoint_hash:
            raise ExperimentConfigurationError("Training checkpoint changed during ONNX export.")
        if file_sha256(source.class_order) != expected_class_order_hash:
            raise ExperimentConfigurationError("Training class order changed during ONNX export.")
        if file_sha256(output_path) != manifest["model_sha256"]:
            raise ExperimentConfigurationError("Staged ONNX model changed after validation.")
        if file_sha256(exported_class_order) != manifest["class_order_sha256"]:
            raise ExperimentConfigurationError("Staged class_order.json changed after validation.")
        model_target, labels_target = promote_onnx_bundle(
            source_model=output_path,
            source_class_order=exported_class_order,
            destination_dir=flutter_assets_dir,
            model_filename=PREFERRED_FLUTTER_MODEL_FILENAME,
            expected_model_sha256=manifest["model_sha256"],
            expected_class_order_sha256=manifest["class_order_sha256"],
        )
        manifest["promoted_to_flutter"] = True
        manifest["promotion_status"] = "complete"
        manifest["flutter_model"] = str(model_target)
        manifest["flutter_class_order"] = str(labels_target)
        # Paired promotion verifies installed target bytes before it returns.
        manifest["flutter_model_sha256"] = manifest["model_sha256"]
        manifest["flutter_class_order_sha256"] = manifest["class_order_sha256"]
        try:
            write_json(manifest, output_dir / "export_manifest.json")
        except OSError as exc:
            print(
                "WARNING: Flutter assets were installed and hash-verified, but the export "
                f"manifest could not be finalized: {exc}"
            )

    if incomplete_cleanup_error is not None:
        raise ExperimentConfigurationError(
            "ONNX export is incomplete because EXPORT_INCOMPLETE could not be removed."
        ) from incomplete_cleanup_error

    print("Staged ONNX export completed")
    print(f"source run: {source.run_dir}")
    print(f"class count: {len(classes)}")
    print(f"staged model: {output_path}")
    print(f"staged class order: {exported_class_order}")
    if not args.promote_to_flutter:
        print("Flutter assets were not modified. Use --promote-to-flutter explicitly after approval.")


if __name__ == "__main__":
    main()
