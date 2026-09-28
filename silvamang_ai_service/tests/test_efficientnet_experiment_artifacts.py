from __future__ import annotations

import csv
import json
import os
import shutil
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import pytest

from training.cnn_classifier.experiment_artifacts import (
    ExperimentConfigurationError,
    PREFERRED_FLUTTER_MODEL_FILENAME,
    PROJECT_ROOT,
    RUNTIME_IMAGE_SIZE,
    STAGED_MANIFEST_COLUMNS,
    SUPPORTED_IMAGE_SUFFIXES,
    assert_path_outside_dataset,
    assert_staging_run_path,
    dataset_fingerprint,
    file_sha256,
    initialize_training_run,
    load_class_order,
    promote_checkpoint_bundle,
    promote_onnx_bundle,
    require_completed_training_run,
    timestamped_run_dir,
    validate_checkpoint_class_order,
    validate_checkpoint_image_size,
    validate_dataset_class_order,
    verify_dataset_fingerprint,
    write_json,
)
from training.cnn_classifier.export_staged_efficientnet_to_onnx import (
    build_argument_parser as build_export_argument_parser,
    main as export_main,
)
from training.cnn_classifier.promote_efficientnet_run import (
    build_argument_parser as build_promotion_argument_parser,
    validate_evaluation_run,
    validate_evaluation_thresholds,
)


def _write_dataset(root: Path, splits: tuple[str, ...], classes: tuple[str, ...]) -> None:
    for split in splits:
        for class_name in classes:
            content = f"test image placeholder:{split}:{class_name}".encode("utf-8")
            digest = __import__("hashlib").sha256(content).hexdigest()
            image = root / split / class_name / f"{digest}.jpg"
            image.parent.mkdir(parents=True, exist_ok=True)
            image.write_bytes(content)


def _write_staged_manifest(root: Path) -> None:
    classes = sorted(path.name for path in (root / "train").iterdir() if path.is_dir())
    input_dir = root / "input_manifests"
    input_dir.mkdir(parents=True, exist_ok=True)
    input_snapshot = input_dir / "test-source.csv"
    staged_images = [
        image
        for split in ("train", "val", "test")
        if (root / split).is_dir()
        for image in sorted((root / split).rglob("*.jpg"))
    ]
    input_rows = []
    for index, image in enumerate(staged_images, start=1):
        relative = image.relative_to(root)
        source_path = image.resolve()
        try:
            displayed_source = source_path.relative_to(PROJECT_ROOT).as_posix()
        except ValueError:
            displayed_source = str(source_path)
        input_rows.append(
            {
                "candidate_id": f"candidate-{index}",
                "approval_status": "approved",
                "scientific_name": relative.parts[1],
                "file_path": displayed_source,
                "source": "test",
                "source_record_id": f"record-{index}",
                "source_record_url": "",
                "source_image_url": "",
                "license": "test-approved",
                "reviewed_plant_part": "leaves",
                "sha256": file_sha256(image),
            }
        )
    with input_snapshot.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(input_rows[0]))
        writer.writeheader()
        writer.writerows(input_rows)

    snapshot_digest = file_sha256(input_snapshot)
    evidence = [
        {
            "source": "tests/fixtures/test-source.csv",
            "sha256": snapshot_digest,
            "snapshot": "input_manifests/test-source.csv",
        }
    ]
    manifest = root / "dataset_manifest.csv"
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=STAGED_MANIFEST_COLUMNS,
        )
        writer.writeheader()
        for row_number, (image, input_row) in enumerate(zip(staged_images, input_rows), start=2):
            relative = image.relative_to(root)
            split, class_name, _ = relative.parts
            digest = file_sha256(image)
            record_key = f"id::test::{input_row['source_record_id']}"
            identity = "\n".join([class_name, digest, record_key])
            group_id = __import__("hashlib").sha256(identity.encode("utf-8")).hexdigest()[:20]
            lineage_item = {
                "entry_id": input_row["candidate_id"],
                "approval_status": "approved",
                "source_file": input_row["file_path"],
                "source_manifest": evidence[0]["source"],
                "source_manifest_sha256": snapshot_digest,
                "source_manifest_snapshot": evidence[0]["snapshot"],
                "source_manifest_row": row_number,
            }
            writer.writerow(
                {
                    "staged_path": relative.as_posix(),
                    "split": split,
                    "class_name": class_name,
                    "sha256": digest,
                    "group_id": group_id,
                    "source_record_keys": json.dumps([record_key]),
                    "entry_id": input_row["candidate_id"],
                    "approval_status": "approved",
                    "source_file": input_row["file_path"],
                    "source_manifest": evidence[0]["source"],
                    "source_manifest_sha256": snapshot_digest,
                    "source_manifest_snapshot": evidence[0]["snapshot"],
                    "source_manifest_row": row_number,
                    "source": "test",
                    "source_record_id": input_row["source_record_id"],
                    "source_record_url": "",
                    "source_image_url": "",
                    "rights_or_license": "test-approved",
                    "reviewed_plant_part": "leaves",
                    "lineage_json": json.dumps([lineage_item], separators=(",", ":")),
                }
            )

    built_at = "2026-09-25T00:00:00+00:00"
    write_json(classes, root / "class_order.json")
    config = {
        "schema_version": 1,
        "status": "staging_only",
        "requires_retraining": True,
        "class_order": classes,
        "input_policy": {
            "required_approval_status": "approved",
            "require_declared_sha256": True,
            "require_source_record": True,
            "require_rights_or_license": True,
        },
        "split": {"group_by": ["sha256", "source_record"]},
        "resolved_input_manifests": evidence,
    }
    write_json(config, root / "config_snapshot.json")
    class_summary = {}
    for class_name in classes:
        counts = {
            split: sum(
                1
                for image in staged_images
                if image.relative_to(root).parts[:2] == (split, class_name)
            )
            for split in ("train", "val", "test")
        }
        class_summary[class_name] = {
            "unique_images": sum(counts.values()),
            "source_groups": sum(counts.values()),
            **counts,
        }
    report = {
        "schema_version": 1,
        "status": "complete",
        "version": "test-v1",
        "built_at": built_at,
        "class_count": len(classes),
        "class_order": classes,
        "accepted_manifest_rows": len(staged_images),
        "unique_images": len(staged_images),
        "duplicate_rows_removed": 0,
        "source_groups": len(staged_images),
        "class_summary": class_summary,
        "input_manifests": evidence,
        "manifest_stats": {},
    }
    write_json(report, root / "build_report.json")
    artifact_hashes = {
        name: file_sha256(root / name)
        for name in (
            "class_order.json",
            "config_snapshot.json",
            "dataset_manifest.csv",
            "build_report.json",
        )
    }
    write_json(
        {
            "schema_version": 1,
            "status": "complete",
            "version": "test-v1",
            "unique_images": len(staged_images),
            "class_count": len(classes),
            "class_order": classes,
            "built_at": built_at,
            "artifact_sha256": artifact_hashes,
            "input_manifests": evidence,
        },
        root / "BUILD_COMPLETE.json",
    )


@pytest.fixture
def scratch_path() -> Path:
    test_root = Path(__file__).resolve().parent / ".test-artifacts"
    test_root.mkdir(exist_ok=True)
    directory = test_root / f"efficientnet-{uuid.uuid4().hex}"
    # tempfile creates mode 0700 directories, which are not accessible in the
    # restricted Windows CI workspace. A normal private test directory works.
    directory.mkdir()
    try:
        yield directory
    finally:
        shutil.rmtree(directory, ignore_errors=True)


def _completed_training_run(
    root: Path,
    *,
    classes: tuple[str, ...] = ("Species_alpha", "unknown"),
) -> tuple[object, Path]:
    dataset = root / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), classes)
    write_json(list(classes), dataset / "class_order.json")
    write_json({"status": "complete"}, dataset / "BUILD_COMPLETE.json")
    _write_staged_manifest(dataset)
    fingerprint = dataset_fingerprint(dataset)

    paths = initialize_training_run(root / "training")
    write_json(list(classes), paths.class_order)
    paths.checkpoint.write_bytes(b"checkpoint")
    marker = {
        "status": "complete",
        "dataset_contract": "staged_builder_v1",
        "dataset_root": str(dataset.resolve()),
        "dataset_fingerprint": fingerprint,
        "image_size": RUNTIME_IMAGE_SIZE,
        "class_order": list(classes),
        "checkpoint_sha256": file_sha256(paths.checkpoint),
        "class_order_sha256": file_sha256(paths.class_order),
    }
    write_json(marker, paths.run_manifest)
    paths.incomplete_marker.unlink()
    write_json(marker, paths.complete_marker)
    return paths, dataset


def _completed_evaluation_run(
    root: Path,
    training_paths,
    dataset: Path,
    *,
    classes: tuple[str, ...] = ("Species_alpha", "unknown"),
) -> Path:
    evaluation = root / "evaluation"
    reports = evaluation / "reports"
    reports.mkdir(parents=True)
    class_order_path = evaluation / "class_order.json"
    metrics_path = reports / "test_metrics.json"
    classification_report_path = reports / "classification_report.csv"
    confusion_matrix_path = reports / "confusion_matrix.png"
    write_json(list(classes), class_order_path)
    write_json(
        {
            "classes": list(classes),
            "accuracy": 0.95,
            "macro_f1": 0.94,
            "per_class": [
                {
                    "class": class_name,
                    "precision": 0.94,
                    "recall": 0.94,
                    "f1": 0.94,
                    "support": 30,
                }
                for class_name in classes
            ],
        },
        metrics_path,
    )
    classification_report_path.write_text(
        "class,precision,recall,f1-score,support\n",
        encoding="utf-8",
    )
    confusion_matrix_path.write_bytes(b"png")
    fingerprint = dataset_fingerprint(dataset)
    marker = {
        "status": "complete",
        "dataset_contract": "staged_builder_v1",
        "source_training_run": str(training_paths.run_dir),
        "dataset_root": str(dataset.resolve()),
        "dataset_fingerprint": fingerprint,
        "image_size": RUNTIME_IMAGE_SIZE,
        "class_order": list(classes),
        "test_metrics": str(metrics_path.resolve()),
        "checkpoint_sha256": file_sha256(training_paths.checkpoint),
        "class_order_sha256": file_sha256(training_paths.class_order),
        "evaluation_artifact_sha256": {
            "class_order.json": file_sha256(class_order_path),
            "reports/test_metrics.json": file_sha256(metrics_path),
            "reports/classification_report.csv": file_sha256(classification_report_path),
            "reports/confusion_matrix.png": file_sha256(confusion_matrix_path),
        },
    }
    write_json(marker, evaluation / "run_manifest.json")
    write_json(marker, evaluation / "RUN_COMPLETE.json")
    return evaluation


def test_timestamped_run_dir_is_versioned_and_utc() -> None:
    result = timestamped_run_dir(
        Path("experiments"),
        now=datetime(2026, 9, 24, 3, 4, 5, 6789, tzinfo=timezone.utc),
    )

    assert result == Path("experiments/run-20260924T030405.006789Z")


def test_active_model_directory_is_rejected_as_run_target(scratch_path: Path) -> None:
    active_server = scratch_path / "server-active"
    active_flutter = scratch_path / "flutter-active"

    with pytest.raises(ExperimentConfigurationError, match="active model location"):
        assert_staging_run_path(
            active_server / "nested-run",
            protected_directories=(active_server, active_flutter),
        )


def test_training_run_refuses_to_overwrite_existing_artifacts(scratch_path: Path) -> None:
    run_dir = scratch_path / "existing-run"
    run_dir.mkdir()
    sentinel = run_dir / "keep.txt"
    sentinel.write_text("keep", encoding="utf-8")

    with pytest.raises(FileExistsError, match="Refusing to overwrite"):
        initialize_training_run(run_dir)

    assert sentinel.read_text(encoding="utf-8") == "keep"


def test_dataset_contract_matches_all_splits_and_declared_order(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    classes = ("Species_alpha", "Species_beta", "unknown")
    _write_dataset(dataset, ("train", "val", "test"), classes)
    write_json(list(classes), dataset / "class_order.json")
    write_json({"status": "complete"}, dataset / "BUILD_COMPLETE.json")
    _write_staged_manifest(dataset)

    result = validate_dataset_class_order(
        dataset,
        splits=("train", "val", "test"),
    )

    assert result == list(classes)


def test_staged_dataset_rejects_unmanifested_image(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    classes = ("Species_alpha", "unknown")
    _write_dataset(dataset, ("train", "val", "test"), classes)
    write_json(list(classes), dataset / "class_order.json")
    write_json({"status": "complete"}, dataset / "BUILD_COMPLETE.json")
    _write_staged_manifest(dataset)
    (dataset / "train" / "Species_alpha" / "extra.jpg").write_bytes(b"extra")

    with pytest.raises(ExperimentConfigurationError, match="unmanifested"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_dataset_contract_rejects_split_class_mismatch(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train",), ("Species_alpha", "Species_beta"))
    _write_dataset(dataset, ("val",), ("Species_alpha",))

    with pytest.raises(ExperimentConfigurationError, match="Class order mismatch"):
        validate_dataset_class_order(dataset, splits=("train", "val"))


def test_dataset_contract_enforces_root_and_explicit_class_orders(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    classes = ("Species_alpha", "Species_beta")
    _write_dataset(dataset, ("train", "val"), classes)
    explicit = scratch_path / "expected.json"
    write_json(["Species_beta", "Species_alpha"], explicit)

    with pytest.raises(ExperimentConfigurationError, match="Class order mismatch"):
        validate_dataset_class_order(
            dataset,
            splits=("train", "val"),
            expected_class_order_path=explicit,
            allow_legacy_dataset=True,
        )


def test_dataset_contract_rejects_incomplete_builder_output(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val"), ("Species_alpha",))
    (dataset / "BUILD_INCOMPLETE").write_text("incomplete", encoding="utf-8")

    with pytest.raises(ExperimentConfigurationError, match="build is incomplete"):
        validate_dataset_class_order(dataset, splits=("train", "val"))


def test_dataset_fingerprint_detects_image_or_manifest_changes(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "unknown"))
    write_json(["Species_alpha", "unknown"], dataset / "class_order.json")
    write_json({"status": "complete"}, dataset / "BUILD_COMPLETE.json")
    manifest = dataset / "dataset_manifest.csv"
    manifest.write_text("staged_path\n", encoding="utf-8")
    fingerprint = dataset_fingerprint(dataset)

    verify_dataset_fingerprint(dataset, fingerprint)
    manifest.write_text("staged_path\nchanged.jpg\n", encoding="utf-8")

    with pytest.raises(ExperimentConfigurationError, match="fingerprint mismatch"):
        verify_dataset_fingerprint(dataset, fingerprint)


def test_class_order_loader_rejects_duplicates(scratch_path: Path) -> None:
    path = scratch_path / "class_order.json"
    write_json(["Species_alpha", "Species_alpha"], path)

    with pytest.raises(ExperimentConfigurationError, match="duplicate"):
        load_class_order(path)


def test_checkpoint_class_order_must_match_file_exactly() -> None:
    checkpoint = {"classes": ["Species_beta", "Species_alpha"]}

    with pytest.raises(ExperimentConfigurationError, match="Class order mismatch"):
        validate_checkpoint_class_order(
            checkpoint,
            ["Species_alpha", "Species_beta"],
        )


@pytest.mark.parametrize("image_size", [None, 223, 225, True])
def test_checkpoint_image_size_must_match_runtime(image_size) -> None:
    with pytest.raises(ExperimentConfigurationError, match="image_size"):
        validate_checkpoint_image_size({"image_size": image_size})

    assert validate_checkpoint_image_size({"image_size": 224}) == 224


def test_completed_run_requires_checkpoint_labels_and_marker(scratch_path: Path) -> None:
    paths = initialize_training_run(scratch_path / "run")
    write_json(["Species_alpha"], paths.class_order)
    paths.checkpoint.write_bytes(b"checkpoint")

    with pytest.raises(ExperimentConfigurationError, match="incomplete"):
        require_completed_training_run(paths.run_dir)

    paths.incomplete_marker.unlink()
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha",))
    write_json(["Species_alpha"], dataset / "class_order.json")
    _write_staged_manifest(dataset)
    write_json(
        {
            "status": "complete",
            "dataset_contract": "staged_builder_v1",
            "class_order": ["Species_alpha"],
            "dataset_root": str(dataset.resolve()),
            "dataset_fingerprint": dataset_fingerprint(dataset),
            "image_size": RUNTIME_IMAGE_SIZE,
            "checkpoint_sha256": file_sha256(paths.checkpoint),
            "class_order_sha256": file_sha256(paths.class_order),
        },
        paths.complete_marker,
    )
    assert require_completed_training_run(paths.run_dir) == paths


def test_export_defaults_to_staging_without_promotion(scratch_path: Path) -> None:
    args = build_export_argument_parser().parse_args(
        ["--source-run-dir", str(scratch_path / "training-run")]
    )

    assert args.output_dir is None
    assert args.promote_to_flutter is False


def test_flutter_promotion_requires_evaluation_and_all_thresholds(
    scratch_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    paths, _ = _completed_training_run(scratch_path)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "export_staged_efficientnet_to_onnx.py",
            "--source-run-dir",
            str(paths.run_dir),
            "--promote-to-flutter",
        ],
    )

    with pytest.raises(ExperimentConfigurationError, match="Missing:.*evaluation-run-dir"):
        export_main()


def test_export_filename_matches_flutter_preferred_asset_contract() -> None:
    dart_service = (
        PROJECT_ROOT
        / "silvamang_mobile"
        / "lib"
        / "features"
        / "identification"
        / "data"
        / "services"
        / "offline_prediction_service.dart"
    ).read_text(encoding="utf-8")
    pubspec = (PROJECT_ROOT / "silvamang_mobile" / "pubspec.yaml").read_text(
        encoding="utf-8"
    )
    asset_path = f"assets/models/{PREFERRED_FLUTTER_MODEL_FILENAME}"

    assert f"'{asset_path}'" in dart_service
    assert f"- {asset_path}" in pubspec
    assert "efficientnet_b0_silvamang.onnx.data" not in dart_service
    assert "efficientnet_b0_silvamang.onnx.data" not in pubspec
    assert "static const int _inputSize = 224;" in dart_service
    assert "static const int _resizeSize = 256;" in dart_service


def test_server_promotion_cli_requires_explicit_thresholds(scratch_path: Path) -> None:
    with pytest.raises(SystemExit):
        build_promotion_argument_parser().parse_args(
            [
                "--source-run-dir",
                str(scratch_path / "training"),
                "--evaluation-run-dir",
                str(scratch_path / "evaluation"),
                "--promote",
            ]
        )


def test_server_promotion_cli_requires_explicit_acknowledgement(
    scratch_path: Path,
) -> None:
    with pytest.raises(SystemExit):
        build_promotion_argument_parser().parse_args(
            [
                "--source-run-dir",
                str(scratch_path / "training"),
                "--evaluation-run-dir",
                str(scratch_path / "evaluation"),
                "--min-accuracy",
                "0.8",
                "--min-macro-f1",
                "0.8",
                "--min-per-class-precision",
                "0.5",
                "--min-per-class-recall",
                "0.5",
                "--min-per-class-f1",
                "0.5",
                "--min-per-class-support",
                "10",
            ]
        )


def test_evaluation_threshold_gate_rejects_weakest_class() -> None:
    classes = ["Species_alpha", "unknown"]
    metrics = {
        "classes": classes,
        "accuracy": 0.91,
        "macro_f1": 0.88,
        "per_class": [
            {"class": "Species_alpha", "precision": 0.90, "recall": 0.90, "f1": 0.90, "support": 30},
            {"class": "unknown", "precision": 0.90, "recall": 0.39, "f1": 0.54, "support": 30},
        ],
    }

    with pytest.raises(ExperimentConfigurationError, match="thresholds were not met"):
        validate_evaluation_thresholds(
            metrics,
            classes,
            minimum_accuracy=0.80,
            minimum_macro_f1=0.80,
            minimum_per_class_precision=0.50,
            minimum_per_class_recall=0.50,
            minimum_per_class_f1=0.50,
            minimum_per_class_support=20,
        )


@pytest.mark.parametrize(
    ("field", "weak_value", "expected_name"),
    [
        ("precision", 0.39, "minimum_per_class_precision"),
        ("f1", 0.39, "minimum_per_class_f1"),
        ("support", 9, "minimum_per_class_support"),
    ],
)
def test_evaluation_gate_checks_every_unknown_class_metric(
    field: str,
    weak_value: float,
    expected_name: str,
) -> None:
    classes = ["Species_alpha", "unknown"]
    rows = [
        {"class": class_name, "precision": 0.9, "recall": 0.9, "f1": 0.9, "support": 30}
        for class_name in classes
    ]
    rows[-1][field] = weak_value
    metrics = {"classes": classes, "accuracy": 0.9, "macro_f1": 0.9, "per_class": rows}

    with pytest.raises(ExperimentConfigurationError, match=expected_name):
        validate_evaluation_thresholds(
            metrics,
            classes,
            minimum_accuracy=0.8,
            minimum_macro_f1=0.8,
            minimum_per_class_precision=0.5,
            minimum_per_class_recall=0.5,
            minimum_per_class_f1=0.5,
            minimum_per_class_support=10,
        )


def test_evaluation_artifact_hashes_are_verified_before_promotion(
    scratch_path: Path,
) -> None:
    training, dataset = _completed_training_run(scratch_path)
    evaluation = _completed_evaluation_run(scratch_path, training, dataset)
    classes = load_class_order(training.class_order)

    validate_evaluation_run(
        training_run_dir=training.run_dir,
        evaluation_run_dir=evaluation,
        classes=classes,
    )
    (evaluation / "reports" / "classification_report.csv").write_text(
        "changed\n",
        encoding="utf-8",
    )

    with pytest.raises(ExperimentConfigurationError, match="changed after completion"):
        validate_evaluation_run(
            training_run_dir=training.run_dir,
            evaluation_run_dir=evaluation,
            classes=classes,
        )


def test_evaluation_run_must_reference_same_dataset_and_training_run(
    scratch_path: Path,
) -> None:
    training = scratch_path / "training"
    evaluation = scratch_path / "evaluation"
    training.mkdir()
    evaluation.mkdir()
    classes = ["Species_alpha", "unknown"]
    training_marker = {
        "status": "complete",
        "dataset_root": str(scratch_path / "dataset-v1"),
    }
    write_json(training_marker, training / "run_manifest.json")
    write_json(training_marker, training / "RUN_COMPLETE.json")
    write_json(classes, evaluation / "class_order.json")
    write_json(
        {
            "status": "complete",
            "source_training_run": str(training),
            "dataset_root": str(scratch_path / "dataset-v2"),
            "class_order": classes,
            "test_metrics": str(evaluation / "reports" / "test_metrics.json"),
        },
        evaluation / "RUN_COMPLETE.json",
    )
    write_json(
        {
            "classes": classes,
            "accuracy": 1.0,
            "macro_f1": 1.0,
            "per_class": [
                {"class": "Species_alpha", "recall": 1.0},
                {"class": "unknown", "recall": 1.0},
            ],
        },
        evaluation / "reports" / "test_metrics.json",
    )
    (evaluation / "reports" / "classification_report.csv").write_text(
        "class,precision,recall,f1-score,support\n",
        encoding="utf-8",
    )
    (evaluation / "reports" / "confusion_matrix.png").write_bytes(b"png")

    with pytest.raises(ExperimentConfigurationError, match="different dataset versions"):
        validate_evaluation_run(
            training_run_dir=training,
            evaluation_run_dir=evaluation,
            classes=classes,
        )


def test_promotion_copies_model_and_class_order_as_a_pair(scratch_path: Path) -> None:
    staged = scratch_path / "staged"
    staged.mkdir()
    model = staged / "model.onnx"
    class_order = staged / "class_order.json"
    model.write_bytes(b"onnx")
    write_json(["Species_alpha", "unknown"], class_order)
    destination = scratch_path / "flutter-assets"

    model_target, labels_target = promote_onnx_bundle(
        source_model=model,
        source_class_order=class_order,
        destination_dir=destination,
    )

    assert model_target.name == PREFERRED_FLUTTER_MODEL_FILENAME
    assert model_target.read_bytes() == b"onnx"
    assert json.loads(labels_target.read_text(encoding="utf-8")) == [
        "Species_alpha",
        "unknown",
    ]


def test_server_promotion_rolls_back_both_files_on_replace_failure(
    scratch_path: Path,
) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active-server"
    staged.mkdir()
    destination.mkdir()
    new_checkpoint = staged / "checkpoint.pth"
    new_labels = staged / "class_order.json"
    new_checkpoint.write_bytes(b"new checkpoint")
    write_json(["Species_alpha", "unknown"], new_labels)
    active_checkpoint = destination / "efficientnet_b0_best.pth"
    active_labels = destination / "class_order.json"
    active_checkpoint.write_bytes(b"old checkpoint")
    write_json(["old_species"], active_labels)
    failed = False

    def fail_second_install(source: Path, target: Path) -> None:
        nonlocal failed
        source_path = Path(source)
        target_path = Path(target)
        if (
            not failed
            and target_path == active_labels
            and source_path.name.endswith(".tmp")
        ):
            failed = True
            raise OSError("simulated label install failure")
        os.replace(source_path, target_path)

    with pytest.raises(OSError, match="simulated label install failure"):
        promote_checkpoint_bundle(
            source_checkpoint=new_checkpoint,
            source_class_order=new_labels,
            destination_dir=destination,
            replace_file=fail_second_install,
        )

    assert active_checkpoint.read_bytes() == b"old checkpoint"
    assert json.loads(active_labels.read_text(encoding="utf-8")) == ["old_species"]


def _rewrite_manifest_rows(dataset: Path, mutate) -> None:
    manifest = dataset / "dataset_manifest.csv"
    with manifest.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = reader.fieldnames
    mutate(rows)
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    marker = json.loads((dataset / "BUILD_COMPLETE.json").read_text(encoding="utf-8"))
    marker["artifact_sha256"]["dataset_manifest.csv"] = file_sha256(manifest)
    write_json(marker, dataset / "BUILD_COMPLETE.json")


def test_partial_builder_bundle_cannot_downgrade_to_legacy(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    (dataset / "config_snapshot.json").unlink()

    with pytest.raises(ExperimentConfigurationError, match="Partial staged builder contract"):
        validate_dataset_class_order(
            dataset,
            splits=("train", "val", "test"),
            allow_legacy_dataset=True,
        )


@pytest.mark.parametrize(
    "classes",
    [
        tuple(f"Species_{index:02d}" for index in range(29)),
        ("Species_alpha", "unknown"),
    ],
)
def test_legacy_opt_in_is_forbidden_for_29_or_unknown_classes(
    scratch_path: Path,
    classes: tuple[str, ...],
) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train",), classes)

    with pytest.raises(ExperimentConfigurationError, match="Legacy dataset opt-in is forbidden"):
        validate_dataset_class_order(
            dataset,
            splits=("train",),
            allow_legacy_dataset=True,
        )


def test_manifest_rejects_unapproved_row_even_with_rehashed_metadata(
    scratch_path: Path,
) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    _rewrite_manifest_rows(dataset, lambda rows: rows[0].update(approval_status="pending"))

    with pytest.raises(ExperimentConfigurationError, match="not explicitly approved"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_manifest_rejects_path_traversal_even_with_rehashed_metadata(
    scratch_path: Path,
) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    _rewrite_manifest_rows(dataset, lambda rows: rows[0].update(staged_path="../outside.jpg"))

    with pytest.raises(ExperimentConfigurationError, match="Invalid staged_path"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_input_manifest_snapshot_mutation_is_rejected(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    snapshot = dataset / "input_manifests" / "test-source.csv"
    snapshot.write_text(snapshot.read_text(encoding="utf-8") + "\n", encoding="utf-8")

    with pytest.raises(ExperimentConfigurationError, match="snapshot hash mismatch"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_run_path_inside_dataset_is_rejected(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    dataset.mkdir()

    with pytest.raises(ExperimentConfigurationError, match="cannot be inside"):
        assert_path_outside_dataset(
            dataset / "training-runs" / "run-1",
            dataset,
            label="Training run directory",
        )


def test_promotion_success_is_not_reversed_by_backup_cleanup_failure(
    scratch_path: Path,
) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active"
    staged.mkdir()
    destination.mkdir()
    checkpoint = staged / "checkpoint.pth"
    labels = staged / "class_order.json"
    checkpoint.write_bytes(b"new")
    write_json(["Species_alpha"], labels)
    (destination / "efficientnet_b0_best.pth").write_bytes(b"old")
    write_json(["old"], destination / "class_order.json")

    def fail_backup_cleanup(path: Path) -> None:
        if path.suffix == ".bak":
            raise PermissionError("simulated retained recovery backup")
        path.unlink(missing_ok=True)

    with pytest.warns(RuntimeWarning, match="cleanup could not remove"):
        model_target, labels_target = promote_checkpoint_bundle(
            source_checkpoint=checkpoint,
            source_class_order=labels,
            destination_dir=destination,
            expected_checkpoint_sha256=file_sha256(checkpoint),
            expected_class_order_sha256=file_sha256(labels),
            cleanup_file=fail_backup_cleanup,
        )

    assert model_target.read_bytes() == b"new"
    assert json.loads(labels_target.read_text(encoding="utf-8")) == ["Species_alpha"]


def test_promotion_rejects_recorded_hash_mismatch_before_mutation(
    scratch_path: Path,
) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active"
    staged.mkdir()
    checkpoint = staged / "checkpoint.pth"
    labels = staged / "class_order.json"
    checkpoint.write_bytes(b"new")
    write_json(["Species_alpha"], labels)

    with pytest.raises(ExperimentConfigurationError, match="recorded hash"):
        promote_checkpoint_bundle(
            source_checkpoint=checkpoint,
            source_class_order=labels,
            destination_dir=destination,
            expected_checkpoint_sha256="0" * 64,
            expected_class_order_sha256=file_sha256(labels),
        )

    assert not (destination / "efficientnet_b0_best.pth").exists()


def test_dataset_rejects_symlink_in_split_tree(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    outside = scratch_path / "outside.jpg"
    outside.write_bytes(b"outside")
    link = dataset / "train" / "Species_alpha" / "linked.jpg"
    try:
        os.symlink(outside, link)
    except OSError as exc:
        pytest.skip(f"Symlink creation is unavailable on this Windows host: {exc}")

    with pytest.raises(ExperimentConfigurationError, match="symlinks|reparse"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_image_suffixes_match_torchvision_and_exclude_gif() -> None:
    assert SUPPORTED_IMAGE_SUFFIXES == {
        ".jpg",
        ".jpeg",
        ".png",
        ".ppm",
        ".bmp",
        ".pgm",
        ".tif",
        ".tiff",
        ".webp",
    }
    assert ".gif" not in SUPPORTED_IMAGE_SUFFIXES


def test_keyboard_interrupt_rolls_back_pair_and_releases_lock(scratch_path: Path) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active"
    staged.mkdir()
    destination.mkdir()
    checkpoint = staged / "checkpoint.pth"
    labels = staged / "class_order.json"
    checkpoint.write_bytes(b"new checkpoint")
    write_json(["Species_alpha"], labels)
    active_checkpoint = destination / "efficientnet_b0_best.pth"
    active_labels = destination / "class_order.json"
    active_checkpoint.write_bytes(b"old checkpoint")
    write_json(["old"], active_labels)
    interrupted = False

    def interrupt_second_install(source: Path, target: Path) -> None:
        nonlocal interrupted
        if not interrupted and Path(target) == active_labels and Path(source).suffix == ".tmp":
            interrupted = True
            raise KeyboardInterrupt()
        os.replace(source, target)

    with pytest.raises(KeyboardInterrupt):
        promote_checkpoint_bundle(
            source_checkpoint=checkpoint,
            source_class_order=labels,
            destination_dir=destination,
            replace_file=interrupt_second_install,
        )

    assert active_checkpoint.read_bytes() == b"old checkpoint"
    assert json.loads(active_labels.read_text(encoding="utf-8")) == ["old"]
    assert not (destination / ".artifact-promotion.lock").exists()


def test_replace_that_commits_then_interrupts_removes_target_when_no_original_existed(
    scratch_path: Path,
) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active"
    staged.mkdir()
    destination.mkdir()
    checkpoint = staged / "checkpoint.pth"
    labels = staged / "class_order.json"
    checkpoint.write_bytes(b"new checkpoint")
    write_json(["Species_alpha"], labels)
    active_checkpoint = destination / "efficientnet_b0_best.pth"
    active_labels = destination / "class_order.json"
    interrupted = False

    def commit_then_interrupt(source: Path, target: Path) -> None:
        nonlocal interrupted
        os.replace(source, target)
        if not interrupted and Path(target) == active_checkpoint:
            interrupted = True
            raise KeyboardInterrupt()

    with pytest.raises(KeyboardInterrupt):
        promote_checkpoint_bundle(
            source_checkpoint=checkpoint,
            source_class_order=labels,
            destination_dir=destination,
            replace_file=commit_then_interrupt,
        )

    assert not active_checkpoint.exists()
    assert not active_labels.exists()
    assert not (destination / ".artifact-promotion.lock").exists()


def test_same_source_record_cannot_be_split_across_two_self_consistent_groups(
    scratch_path: Path,
) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)

    manifest_path = dataset / "dataset_manifest.csv"
    with manifest_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = reader.fieldnames
    first = next(row for row in rows if row["split"] == "train" and row["class_name"] == "Species_alpha")
    second = next(row for row in rows if row["split"] == "test" and row["class_name"] == "Species_alpha")
    common_record_id = first["source_record_id"]
    common_key = f"id::test::{common_record_id}"

    snapshot_path = dataset / first["source_manifest_snapshot"]
    with snapshot_path.open("r", encoding="utf-8", newline="") as handle:
        snapshot_reader = csv.DictReader(handle)
        snapshot_rows = list(snapshot_reader)
        snapshot_fields = snapshot_reader.fieldnames
    snapshot_rows[int(second["source_manifest_row"]) - 2]["source_record_id"] = common_record_id
    with snapshot_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=snapshot_fields)
        writer.writeheader()
        writer.writerows(snapshot_rows)
    new_snapshot_hash = file_sha256(snapshot_path)

    for row in rows:
        row["source_manifest_sha256"] = new_snapshot_hash
        lineage = json.loads(row["lineage_json"])
        for item in lineage:
            item["source_manifest_sha256"] = new_snapshot_hash
        row["lineage_json"] = json.dumps(lineage, separators=(",", ":"))
    second["source_record_id"] = common_record_id
    second["source_record_keys"] = json.dumps([common_key])
    for row in (first, second):
        identity = "\n".join([row["class_name"], row["sha256"], common_key])
        row["group_id"] = __import__("hashlib").sha256(identity.encode("utf-8")).hexdigest()[:20]
    with manifest_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    config_path = dataset / "config_snapshot.json"
    report_path = dataset / "build_report.json"
    marker_path = dataset / "BUILD_COMPLETE.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    report = json.loads(report_path.read_text(encoding="utf-8"))
    marker = json.loads(marker_path.read_text(encoding="utf-8"))
    config["resolved_input_manifests"][0]["sha256"] = new_snapshot_hash
    report["input_manifests"][0]["sha256"] = new_snapshot_hash
    marker["input_manifests"][0]["sha256"] = new_snapshot_hash
    write_json(config, config_path)
    write_json(report, report_path)
    marker["artifact_sha256"] = {
        name: file_sha256(dataset / name)
        for name in (
            "class_order.json",
            "config_snapshot.json",
            "dataset_manifest.csv",
            "build_report.json",
        )
    }
    write_json(marker, marker_path)

    with pytest.raises(ExperimentConfigurationError, match="multiple groups, classes, or splits"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_manifest_lineage_totals_must_match_build_report(scratch_path: Path) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    report_path = dataset / "build_report.json"
    marker_path = dataset / "BUILD_COMPLETE.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["accepted_manifest_rows"] += 1
    report["duplicate_rows_removed"] += 1
    write_json(report, report_path)
    marker = json.loads(marker_path.read_text(encoding="utf-8"))
    marker["artifact_sha256"]["build_report.json"] = file_sha256(report_path)
    write_json(marker, marker_path)

    with pytest.raises(ExperimentConfigurationError, match="approval lineage"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_lineage_cannot_omit_an_approved_row_and_duplicate_another(
    scratch_path: Path,
) -> None:
    dataset = scratch_path / "dataset"
    _write_dataset(dataset, ("train", "val", "test"), ("Species_alpha", "Species_beta"))
    _write_staged_manifest(dataset)
    manifest_path = dataset / "dataset_manifest.csv"
    with manifest_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = reader.fieldnames
    target_row = rows[0]
    snapshot_path = dataset / target_row["source_manifest_snapshot"]
    with snapshot_path.open("r", encoding="utf-8", newline="") as handle:
        snapshot_reader = csv.DictReader(handle)
        snapshot_rows = list(snapshot_reader)
        snapshot_fields = snapshot_reader.fieldnames
    omitted = dict(snapshot_rows[int(target_row["source_manifest_row"]) - 2])
    omitted["candidate_id"] = "approved-but-omitted"
    snapshot_rows.append(omitted)
    with snapshot_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=snapshot_fields)
        writer.writeheader()
        writer.writerows(snapshot_rows)
    snapshot_hash = file_sha256(snapshot_path)

    for row in rows:
        row["source_manifest_sha256"] = snapshot_hash
        lineage = json.loads(row["lineage_json"])
        for item in lineage:
            item["source_manifest_sha256"] = snapshot_hash
        row["lineage_json"] = json.dumps(lineage, separators=(",", ":"))
    duplicated = json.loads(target_row["lineage_json"])[0]
    target_row["lineage_json"] = json.dumps([duplicated, duplicated], separators=(",", ":"))
    with manifest_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    config_path = dataset / "config_snapshot.json"
    report_path = dataset / "build_report.json"
    marker_path = dataset / "BUILD_COMPLETE.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    report = json.loads(report_path.read_text(encoding="utf-8"))
    marker = json.loads(marker_path.read_text(encoding="utf-8"))
    config["resolved_input_manifests"][0]["sha256"] = snapshot_hash
    report["input_manifests"][0]["sha256"] = snapshot_hash
    report["accepted_manifest_rows"] += 1
    report["duplicate_rows_removed"] += 1
    marker["input_manifests"][0]["sha256"] = snapshot_hash
    write_json(config, config_path)
    write_json(report, report_path)
    marker["artifact_sha256"] = {
        name: file_sha256(dataset / name)
        for name in (
            "class_order.json",
            "config_snapshot.json",
            "dataset_manifest.csv",
            "build_report.json",
        )
    }
    write_json(marker, marker_path)

    with pytest.raises(ExperimentConfigurationError, match="appears more than once"):
        validate_dataset_class_order(dataset, splits=("train", "val", "test"))


def test_existing_promotion_lock_preserves_original_error_and_assets(
    scratch_path: Path,
) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active"
    staged.mkdir()
    destination.mkdir()
    checkpoint = staged / "checkpoint.pth"
    labels = staged / "class_order.json"
    checkpoint.write_bytes(b"new")
    write_json(["Species_alpha"], labels)
    active_checkpoint = destination / "efficientnet_b0_best.pth"
    active_labels = destination / "class_order.json"
    active_checkpoint.write_bytes(b"old")
    write_json(["old"], active_labels)
    lock = destination / ".artifact-promotion.lock"
    lock.write_text("other-transaction\n", encoding="utf-8")

    with pytest.raises(ExperimentConfigurationError, match="Another artifact promotion"):
        promote_checkpoint_bundle(
            source_checkpoint=checkpoint,
            source_class_order=labels,
            destination_dir=destination,
        )

    assert active_checkpoint.read_bytes() == b"old"
    assert json.loads(active_labels.read_text(encoding="utf-8")) == ["old"]
    assert lock.read_text(encoding="utf-8") == "other-transaction\n"


def test_cleanup_keyboard_interrupt_does_not_turn_committed_pair_into_failure(
    scratch_path: Path,
) -> None:
    staged = scratch_path / "staged"
    destination = scratch_path / "active"
    staged.mkdir()
    destination.mkdir()
    checkpoint = staged / "checkpoint.pth"
    labels = staged / "class_order.json"
    checkpoint.write_bytes(b"new")
    write_json(["Species_alpha"], labels)
    (destination / "efficientnet_b0_best.pth").write_bytes(b"old")
    write_json(["old"], destination / "class_order.json")

    def interrupt_backup_cleanup(path: Path) -> None:
        if path.suffix == ".bak":
            raise KeyboardInterrupt()
        path.unlink(missing_ok=True)

    with pytest.warns(RuntimeWarning, match="cleanup could not remove"):
        checkpoint_target, labels_target = promote_checkpoint_bundle(
            source_checkpoint=checkpoint,
            source_class_order=labels,
            destination_dir=destination,
            cleanup_file=interrupt_backup_cleanup,
        )

    assert checkpoint_target.read_bytes() == b"new"
    assert json.loads(labels_target.read_text(encoding="utf-8")) == ["Species_alpha"]
    assert not (destination / ".artifact-promotion.lock").exists()
