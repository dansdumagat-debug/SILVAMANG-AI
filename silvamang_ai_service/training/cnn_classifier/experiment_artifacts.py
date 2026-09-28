from __future__ import annotations

import csv
import json
import hashlib
import os
import shutil
import stat
import uuid
import warnings
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Iterable, Sequence
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


AI_SERVICE_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = AI_SERVICE_ROOT.parent
DEFAULT_DATASET_ROOT = PROJECT_ROOT / "dataset" / "processed" / "cnn_classification"
DEFAULT_EXPERIMENT_ROOT = AI_SERVICE_ROOT / "artifacts" / "efficientnet_transfer"
ACTIVE_SERVER_MODEL_DIR = AI_SERVICE_ROOT / "models" / "cnn_classifier"
ACTIVE_FLUTTER_MODEL_DIR = PROJECT_ROOT / "silvamang_mobile" / "assets" / "models"
PREFERRED_FLUTTER_MODEL_FILENAME = "efficientnet_b0_silvamang_single.onnx"
RUNTIME_IMAGE_SIZE = 224
RUNTIME_RESIZE_SIZE = 256
DATASET_FINGERPRINT_SCHEMA = "sha256-tree-v1"

SUPPORTED_IMAGE_SUFFIXES = {
    ".bmp",
    ".jpeg",
    ".jpg",
    ".pgm",
    ".png",
    ".ppm",
    ".tif",
    ".tiff",
    ".webp",
}

STAGED_DATASET_REQUIRED_FILES = (
    "BUILD_COMPLETE.json",
    "dataset_manifest.csv",
    "config_snapshot.json",
    "class_order.json",
    "build_report.json",
)
STAGED_MANIFEST_COLUMNS = (
    "staged_path",
    "split",
    "class_name",
    "sha256",
    "group_id",
    "source_record_keys",
    "entry_id",
    "approval_status",
    "source_file",
    "source_manifest",
    "source_manifest_sha256",
    "source_manifest_snapshot",
    "source_manifest_row",
    "source",
    "source_record_id",
    "source_record_url",
    "source_image_url",
    "rights_or_license",
    "reviewed_plant_part",
    "lineage_json",
)
STAGED_MANIFEST_FIELDS = set(STAGED_MANIFEST_COLUMNS)
BUILDER_HASHED_ARTIFACTS = {
    "class_order.json",
    "config_snapshot.json",
    "dataset_manifest.csv",
    "build_report.json",
}


class ExperimentConfigurationError(ValueError):
    """Raised before a run when an experiment bundle is unsafe or inconsistent."""


@dataclass(frozen=True)
class ExperimentPaths:
    run_dir: Path
    checkpoint: Path
    class_order: Path
    reports_dir: Path
    training_history: Path
    validation_metrics: Path
    run_manifest: Path
    incomplete_marker: Path
    complete_marker: Path
    exports_dir: Path
    onnx_model: Path
    exported_class_order: Path


def timestamped_run_dir(
    root: Path = DEFAULT_EXPERIMENT_ROOT,
    *,
    now: datetime | None = None,
    prefix: str = "run",
) -> Path:
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    timestamp = moment.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    return Path(root) / f"{prefix}-{timestamp}"


def experiment_paths(run_dir: Path) -> ExperimentPaths:
    resolved = Path(run_dir).expanduser().resolve()
    reports = resolved / "reports"
    exports = resolved / "exports"
    return ExperimentPaths(
        run_dir=resolved,
        checkpoint=resolved / "checkpoints" / "efficientnet_b0_best.pth",
        class_order=resolved / "class_order.json",
        reports_dir=reports,
        training_history=reports / "training_history.csv",
        validation_metrics=reports / "val_metrics.json",
        run_manifest=resolved / "run_manifest.json",
        incomplete_marker=resolved / "RUN_INCOMPLETE",
        complete_marker=resolved / "RUN_COMPLETE.json",
        exports_dir=exports,
        onnx_model=exports / PREFERRED_FLUTTER_MODEL_FILENAME,
        exported_class_order=exports / "class_order.json",
    )


def _is_same_or_descendant(path: Path, parent: Path) -> bool:
    return path == parent or parent in path.parents


def _is_reparse_point(path: Path) -> bool:
    try:
        metadata = os.lstat(path)
    except OSError as exc:
        raise ExperimentConfigurationError(f"Unable to inspect dataset path {path}: {exc}") from exc
    attributes = getattr(metadata, "st_file_attributes", 0)
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    is_junction = getattr(path, "is_junction", lambda: False)()
    return path.is_symlink() or is_junction or bool(attributes & reparse_flag)


def reject_reparse_points(root_path: Path) -> Path:
    """Reject symlinks, junctions, and other reparse points without following them."""

    requested = Path(root_path).expanduser().absolute()
    if not requested.exists():
        raise FileNotFoundError(f"Dataset root not found: {requested}")
    if _is_reparse_point(requested):
        raise ExperimentConfigurationError(
            f"Dataset root cannot be a symlink, junction, or reparse point: {requested}"
        )
    root = requested.resolve()
    stack = [requested]
    while stack:
        directory = stack.pop()
        try:
            entries = list(os.scandir(directory))
        except OSError as exc:
            raise ExperimentConfigurationError(
                f"Unable to inspect dataset directory {directory}: {exc}"
            ) from exc
        for entry in entries:
            path = Path(entry.path)
            if _is_reparse_point(path):
                raise ExperimentConfigurationError(
                    "Dataset cannot contain symlinks, junctions, or reparse points: "
                    f"{path}"
                )
            resolved = path.resolve()
            if not _is_same_or_descendant(resolved, root):
                raise ExperimentConfigurationError(
                    f"Dataset path resolves outside its root: {path}"
                )
            if entry.is_dir(follow_symlinks=False):
                stack.append(path)
    return root


def assert_path_outside_dataset(path: Path, dataset_root: Path, *, label: str) -> Path:
    resolved_path = Path(path).expanduser().resolve()
    root = Path(dataset_root).expanduser().resolve()
    if _is_same_or_descendant(resolved_path, root):
        raise ExperimentConfigurationError(
            f"{label} cannot be inside the dataset root: path={resolved_path}, dataset={root}."
        )
    return resolved_path


def assert_staging_run_path(
    run_dir: Path,
    *,
    protected_directories: Iterable[Path] | None = None,
) -> Path:
    resolved = Path(run_dir).expanduser().resolve()
    protected = tuple(
        Path(path).expanduser().resolve()
        for path in (
            protected_directories
            if protected_directories is not None
            else (ACTIVE_SERVER_MODEL_DIR, ACTIVE_FLUTTER_MODEL_DIR)
        )
    )
    for directory in protected:
        if _is_same_or_descendant(resolved, directory):
            raise ExperimentConfigurationError(
                f"Run directory is inside an active model location: {resolved}. "
                "Choose a versioned staging directory instead."
            )
    return resolved


def initialize_training_run(run_dir: Path) -> ExperimentPaths:
    paths = experiment_paths(assert_staging_run_path(run_dir))
    if paths.run_dir.exists() and any(paths.run_dir.iterdir()):
        raise FileExistsError(
            f"Refusing to overwrite non-empty experiment run: {paths.run_dir}"
        )

    paths.run_dir.mkdir(parents=True, exist_ok=True)
    paths.checkpoint.parent.mkdir(parents=True, exist_ok=True)
    paths.reports_dir.mkdir(parents=True, exist_ok=True)
    paths.incomplete_marker.write_text(
        "Training has not completed. Do not evaluate, export, or promote this run.\n",
        encoding="utf-8",
    )
    return paths


def require_completed_training_run(run_dir: Path) -> ExperimentPaths:
    paths = experiment_paths(assert_staging_run_path(run_dir))
    missing = [
        path
        for path in (paths.checkpoint, paths.class_order, paths.complete_marker)
        if not path.is_file()
    ]
    if paths.incomplete_marker.exists() or missing:
        details = ", ".join(str(path) for path in missing) or str(paths.incomplete_marker)
        raise ExperimentConfigurationError(
            f"Training run is incomplete or missing required artifacts: {details}"
        )
    marker = load_json_object(paths.complete_marker, description="training completion marker")
    if marker.get("status") != "complete":
        raise ExperimentConfigurationError(
            f"Training completion marker does not have status=complete: {paths.complete_marker}"
        )
    if marker.get("dataset_contract") not in {"staged_builder_v1", "legacy_explicit"}:
        raise ExperimentConfigurationError(
            f"Training completion marker has no supported dataset_contract: {paths.complete_marker}"
        )
    classes = load_class_order(paths.class_order)
    marker_classes = marker.get("class_order")
    if not isinstance(marker_classes, list):
        raise ExperimentConfigurationError(
            f"Training completion marker has no class_order list: {paths.complete_marker}"
        )
    require_same_class_order(
        classes,
        marker_classes,
        expected_name=str(paths.class_order),
        actual_name=str(paths.complete_marker),
    )
    for field, artifact in (
        ("checkpoint_sha256", paths.checkpoint),
        ("class_order_sha256", paths.class_order),
    ):
        expected_hash = marker.get(field)
        if not isinstance(expected_hash, str) or len(expected_hash) != 64:
            raise ExperimentConfigurationError(
                f"Training completion marker has no valid {field}: {paths.complete_marker}"
            )
        actual_hash = file_sha256(artifact)
        if actual_hash != expected_hash.lower():
            raise ExperimentConfigurationError(
                f"Completed training artifact changed after the run: {artifact}"
            )
    image_size = marker.get("image_size")
    if image_size != RUNTIME_IMAGE_SIZE:
        raise ExperimentConfigurationError(
            "Completed training run has an incompatible image size: "
            f"expected={RUNTIME_IMAGE_SIZE}, recorded={image_size!r}."
        )
    dataset_root_value = marker.get("dataset_root")
    if not isinstance(dataset_root_value, str) or not dataset_root_value.strip():
        raise ExperimentConfigurationError(
            f"Training completion marker has no dataset_root: {paths.complete_marker}"
        )
    dataset_root = Path(dataset_root_value).expanduser().resolve()
    assert_path_outside_dataset(
        paths.run_dir,
        dataset_root,
        label="Completed training run directory",
    )
    expected_fingerprint = marker.get("dataset_fingerprint")
    if not isinstance(expected_fingerprint, dict):
        raise ExperimentConfigurationError(
            f"Training completion marker has no dataset_fingerprint: {paths.complete_marker}"
        )
    verify_dataset_fingerprint(dataset_root, expected_fingerprint)
    dataset_classes = validate_dataset_class_order(
        dataset_root,
        splits=("train", "val", "test"),
        allow_legacy_dataset=marker["dataset_contract"] == "legacy_explicit",
    )
    require_same_class_order(
        classes,
        dataset_classes,
        expected_name=str(paths.class_order),
        actual_name=f"completed dataset under {dataset_root}",
    )
    return paths


def write_json(payload: object, path: Path) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.parent / f".{destination.name}.{uuid.uuid4().hex}.tmp"
    try:
        with temporary.open("w", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(payload, indent=2) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, destination)
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except BaseException:
            pass


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def dataset_fingerprint(dataset_root: Path) -> dict:
    """Hash every regular file in an immutable, completed staged dataset tree."""

    root = reject_reparse_points(dataset_root)
    if not root.is_dir():
        raise FileNotFoundError(f"Dataset root not found: {root}")

    records: list[tuple[str, int, str]] = []
    total_bytes = 0
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        if not path.is_file():
            continue
        resolved = path.resolve()
        if not _is_same_or_descendant(resolved, root):
            raise ExperimentConfigurationError(
                f"Dataset contains a file that resolves outside its root: {path}"
            )
        before = resolved.stat()
        digest = file_sha256(resolved)
        after = resolved.stat()
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            raise ExperimentConfigurationError(
                f"Dataset file changed while it was being fingerprinted: {resolved}"
            )
        relative = path.relative_to(root).as_posix()
        records.append((relative, after.st_size, digest))
        total_bytes += after.st_size

    if not records:
        raise ExperimentConfigurationError(f"Dataset contains no files: {root}")

    aggregate = hashlib.sha256()
    for relative, size, digest in records:
        aggregate.update(
            json.dumps(
                [relative, size, digest],
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
        )
        aggregate.update(b"\n")

    result = {
        "schema": DATASET_FINGERPRINT_SCHEMA,
        "sha256": aggregate.hexdigest(),
        "file_count": len(records),
        "total_bytes": total_bytes,
    }
    for filename, field in (
        ("dataset_manifest.csv", "dataset_manifest_sha256"),
        ("class_order.json", "class_order_sha256"),
        ("BUILD_COMPLETE.json", "build_complete_sha256"),
    ):
        metadata_path = root / filename
        if metadata_path.is_file():
            result[field] = file_sha256(metadata_path)
    return result


def require_same_dataset_fingerprint(
    expected: object,
    actual: object,
    *,
    expected_name: str,
    actual_name: str,
) -> None:
    required = ("schema", "sha256", "file_count", "total_bytes")
    if not isinstance(expected, dict) or any(field not in expected for field in required):
        raise ExperimentConfigurationError(
            f"{expected_name} has no valid dataset fingerprint."
        )
    if not isinstance(actual, dict) or any(field not in actual for field in required):
        raise ExperimentConfigurationError(f"{actual_name} has no valid dataset fingerprint.")
    if expected != actual:
        raise ExperimentConfigurationError(
            "Dataset fingerprint mismatch between "
            f"{expected_name} and {actual_name}: "
            f"expected={expected.get('sha256')}, actual={actual.get('sha256')}."
        )


def verify_dataset_fingerprint(dataset_root: Path, expected: object) -> dict:
    actual = dataset_fingerprint(dataset_root)
    require_same_dataset_fingerprint(
        expected,
        actual,
        expected_name="recorded completed dataset",
        actual_name=str(Path(dataset_root).expanduser().resolve()),
    )
    return actual


def load_json_object(path: Path, *, description: str = "JSON document") -> dict:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ExperimentConfigurationError(
            f"Invalid {description} at {path}: {exc}"
        ) from exc
    if not isinstance(payload, dict):
        raise ExperimentConfigurationError(f"{description.capitalize()} must be a JSON object: {path}")
    return payload


def load_class_order(path: Path) -> list[str]:
    source = Path(path)
    if not source.is_file():
        raise FileNotFoundError(f"Class order file not found: {source}")
    try:
        payload = json.loads(source.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ExperimentConfigurationError(
            f"Class order is not valid JSON: {source}: {exc}"
        ) from exc
    if not isinstance(payload, list) or not payload:
        raise ExperimentConfigurationError(
            f"Class order must be a non-empty JSON list: {source}"
        )
    if not all(isinstance(item, str) and item.strip() == item and item for item in payload):
        raise ExperimentConfigurationError(
            f"Every class label must be a non-empty, trimmed string: {source}"
        )
    if len(set(payload)) != len(payload):
        raise ExperimentConfigurationError(f"Class order contains duplicate labels: {source}")
    return list(payload)


def require_same_class_order(
    expected: Sequence[str],
    actual: Sequence[str],
    *,
    expected_name: str,
    actual_name: str,
) -> None:
    expected_list = list(expected)
    actual_list = list(actual)
    if expected_list == actual_list:
        return

    missing = [name for name in expected_list if name not in actual_list]
    unexpected = [name for name in actual_list if name not in expected_list]
    first_difference = next(
        (
            index
            for index, pair in enumerate(zip(expected_list, actual_list))
            if pair[0] != pair[1]
        ),
        min(len(expected_list), len(actual_list)),
    )
    raise ExperimentConfigurationError(
        f"Class order mismatch between {expected_name} ({len(expected_list)} classes) "
        f"and {actual_name} ({len(actual_list)} classes). "
        f"First differing index: {first_difference}; missing: {missing or 'none'}; "
        f"unexpected: {unexpected or 'none'}."
    )


def _split_class_order(split_dir: Path) -> list[str]:
    if not split_dir.is_dir():
        raise FileNotFoundError(f"Dataset split directory not found: {split_dir}")
    classes = sorted(path.name for path in split_dir.iterdir() if path.is_dir())
    if not classes:
        raise ExperimentConfigurationError(f"No class folders found in {split_dir}")

    empty = []
    for class_name in classes:
        class_dir = split_dir / class_name
        if not any(
            file.is_file() and file.suffix.lower() in SUPPORTED_IMAGE_SUFFIXES
            for file in class_dir.rglob("*")
        ):
            empty.append(class_name)
    if empty:
        raise ExperimentConfigurationError(
            f"Dataset split {split_dir.name} has empty class folders: {', '.join(empty)}"
        )
    return classes


def _validated_sha256(value: object, *, context: str) -> str:
    digest = value.strip().lower() if isinstance(value, str) else ""
    if len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        raise ExperimentConfigurationError(f"Invalid SHA-256 for {context}.")
    return digest


def _safe_relative_file(root: Path, value: object, *, context: str) -> tuple[str, Path]:
    text = value.strip() if isinstance(value, str) else ""
    relative = PurePosixPath(text)
    if (
        not text
        or relative.is_absolute()
        or any(part in {"", ".", ".."} for part in relative.parts)
    ):
        raise ExperimentConfigurationError(f"Unsafe relative path for {context}: {text!r}")
    candidate = root.joinpath(*relative.parts)
    if _is_reparse_point(candidate):
        raise ExperimentConfigurationError(f"Reparse point is forbidden for {context}: {candidate}")
    resolved = candidate.resolve()
    if not _is_same_or_descendant(resolved, root) or not resolved.is_file():
        raise ExperimentConfigurationError(
            f"Referenced file is missing or outside the dataset for {context}: {text}"
        )
    return relative.as_posix(), resolved


def _normalized_input_manifest_evidence(payload: object, root: Path, *, context: str) -> list[dict]:
    if not isinstance(payload, list) or not payload:
        raise ExperimentConfigurationError(f"{context} must contain input manifest evidence.")
    normalized: list[dict] = []
    seen_snapshots: set[str] = set()
    for index, item in enumerate(payload):
        if not isinstance(item, dict):
            raise ExperimentConfigurationError(f"Invalid input manifest evidence in {context}.")
        source = item.get("source")
        if not isinstance(source, str) or not source.strip():
            raise ExperimentConfigurationError(f"Missing input manifest source in {context}.")
        snapshot, snapshot_path = _safe_relative_file(
            root,
            item.get("snapshot"),
            context=f"{context} input manifest {index}",
        )
        if not snapshot.startswith("input_manifests/") or snapshot in seen_snapshots:
            raise ExperimentConfigurationError(
                f"Invalid or duplicate input manifest snapshot in {context}: {snapshot}"
            )
        digest = _validated_sha256(item.get("sha256"), context=f"{context} {snapshot}")
        if file_sha256(snapshot_path) != digest:
            raise ExperimentConfigurationError(
                f"Input manifest snapshot hash mismatch in {context}: {snapshot}"
            )
        normalized.append({"source": source.strip(), "sha256": digest, "snapshot": snapshot})
        seen_snapshots.add(snapshot)
    return normalized


def _first_manifest_value(row: dict[str, str], fields: Sequence[str]) -> str:
    for field in fields:
        value = str(row.get(field) or "").strip()
        if value:
            return value
    return ""


def _normalized_manifest_url(value: str) -> str:
    try:
        parsed = urlsplit(value.strip())
    except ValueError:
        return value.strip().casefold()
    if not parsed.scheme or not parsed.netloc:
        return value.strip().casefold()
    path = parsed.path.rstrip("/") or "/"
    ignored = {"fbclid", "gclid", "mc_cid", "mc_eid"}
    query = urlencode(
        sorted(
            (key, item)
            for key, item in parse_qsl(parsed.query, keep_blank_values=True)
            if not key.casefold().startswith("utm_") and key.casefold() not in ignored
        ),
        doseq=True,
    )
    return urlunsplit(
        (parsed.scheme.casefold(), parsed.netloc.casefold(), path, query, "")
    )


def _display_source_file(value: str) -> str:
    source = Path(value)
    if not source.is_absolute():
        source = PROJECT_ROOT / source
    source = source.resolve()
    try:
        return source.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return str(source)


def _load_snapshot_rows(
    root: Path,
    evidence_by_snapshot: dict[str, dict[str, str]],
) -> dict[str, dict[int, dict[str, str]]]:
    snapshots: dict[str, dict[int, dict[str, str]]] = {}
    for snapshot in evidence_by_snapshot:
        snapshot_path = root.joinpath(*PurePosixPath(snapshot).parts)
        try:
            with snapshot_path.open("r", encoding="utf-8-sig", newline="") as handle:
                reader = csv.DictReader(handle)
                if not reader.fieldnames:
                    raise ExperimentConfigurationError(
                        f"Input manifest snapshot has no header: {snapshot}"
                    )
                snapshots[snapshot] = {
                    row_number: {str(key): str(value or "") for key, value in row.items()}
                    for row_number, row in enumerate(reader, start=2)
                }
        except (OSError, UnicodeDecodeError, csv.Error) as exc:
            raise ExperimentConfigurationError(
                f"Unable to read input manifest snapshot {snapshot}: {exc}"
            ) from exc
    return snapshots


def _snapshot_row_contract(
    row: dict[str, str],
    *,
    row_number: int,
    manifest_source: str,
) -> dict[str, object]:
    approval_values = {
        str(row.get(field) or "").strip().casefold()
        for field in ("review_status", "approval_status")
        if str(row.get(field) or "").strip()
    }
    approval = next(iter(approval_values), "") if len(approval_values) == 1 else ""
    class_name = "_".join(
        _first_manifest_value(
            row, ("scientific_name", "species_scientific_name", "class_name")
        )
        .replace("_", " ")
        .split()
    )
    entry_id = _first_manifest_value(row, ("candidate_id", "image_id", "entry_id"))
    if not entry_id:
        entry_id = f"{Path(manifest_source).name}:{row_number}"
    source = _first_manifest_value(row, ("source",))
    source_record_id = _first_manifest_value(
        row, ("source_record_id", "source_group_id", "observation_id")
    )
    source_record_url = _first_manifest_value(row, ("source_record_url",))
    keys: list[str] = []
    if source and source_record_id:
        keys.append(f"id::{' '.join(source.casefold().split())}::{source_record_id.strip()}")
    if source_record_url:
        keys.append(f"url::{_normalized_manifest_url(source_record_url)}")
    raw_file = _first_manifest_value(row, ("file_path", "source_path"))
    return {
        "approval_status": approval,
        "class_name": class_name,
        "entry_id": entry_id,
        "source_file": _display_source_file(raw_file) if raw_file else "",
        "source": source,
        "source_record_id": source_record_id,
        "source_record_url": source_record_url,
        "source_image_url": _first_manifest_value(row, ("source_image_url",)),
        "rights_or_license": _first_manifest_value(row, ("license", "permission_status")),
        "reviewed_plant_part": _first_manifest_value(
            row, ("reviewed_plant_part", "plant_part")
        ),
        "sha256": _first_manifest_value(row, ("sha256",)).casefold(),
        "source_record_keys": keys,
    }


def _validate_builder_contract(
    root: Path,
    classes: Sequence[str],
) -> tuple[str, dict[str, dict[str, str]]]:
    paths = {name: root / name for name in STAGED_DATASET_REQUIRED_FILES}
    missing = [name for name, path in paths.items() if not path.is_file()]
    if missing:
        raise ExperimentConfigurationError(
            "Staged dataset is missing required builder artifacts: " + ", ".join(missing)
        )
    if (root / "BUILD_INCOMPLETE").exists():
        raise ExperimentConfigurationError(
            f"Dataset staging build is incomplete: {root / 'BUILD_INCOMPLETE'}"
        )

    marker = load_json_object(paths["BUILD_COMPLETE.json"], description="dataset completion marker")
    config = load_json_object(paths["config_snapshot.json"], description="dataset config snapshot")
    report = load_json_object(paths["build_report.json"], description="dataset build report")
    expected_marker_fields = {
        "schema_version",
        "status",
        "version",
        "unique_images",
        "class_count",
        "class_order",
        "built_at",
        "artifact_sha256",
        "input_manifests",
    }
    expected_report_fields = {
        "schema_version",
        "status",
        "version",
        "built_at",
        "class_count",
        "class_order",
        "accepted_manifest_rows",
        "unique_images",
        "duplicate_rows_removed",
        "source_groups",
        "class_summary",
        "input_manifests",
        "manifest_stats",
    }
    if set(marker) != expected_marker_fields:
        raise ExperimentConfigurationError(
            "BUILD_COMPLETE.json schema differs from the staged builder contract."
        )
    if set(report) != expected_report_fields:
        raise ExperimentConfigurationError(
            "build_report.json schema differs from the staged builder contract."
        )
    if marker.get("schema_version") != 1 or marker.get("status") != "complete":
        raise ExperimentConfigurationError("BUILD_COMPLETE.json is not a supported complete marker.")
    if config.get("schema_version") != 1 or config.get("status") != "staging_only":
        raise ExperimentConfigurationError("config_snapshot.json is not a supported staging policy.")
    if config.get("requires_retraining") is not True:
        raise ExperimentConfigurationError("Staged config must declare requires_retraining=true.")
    if report.get("schema_version") != 1 or report.get("status") != "complete":
        raise ExperimentConfigurationError("build_report.json is not a supported complete report.")

    for source_name, payload in (
        ("BUILD_COMPLETE.json", marker.get("class_order")),
        ("config_snapshot.json", config.get("class_order")),
        ("build_report.json", report.get("class_order")),
    ):
        if not isinstance(payload, list):
            raise ExperimentConfigurationError(f"{source_name} has no class_order list.")
        require_same_class_order(
            classes,
            payload,
            expected_name="dataset class_order.json",
            actual_name=source_name,
        )
    for source_name, payload in (("BUILD_COMPLETE.json", marker), ("build_report.json", report)):
        if payload.get("class_count") != len(classes):
            raise ExperimentConfigurationError(f"{source_name} class_count is inconsistent.")
    for field in (
        "unique_images",
        "accepted_manifest_rows",
        "duplicate_rows_removed",
        "source_groups",
    ):
        if field not in report:
            continue
        value = report.get(field)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise ExperimentConfigurationError(
                f"build_report.json has invalid {field}."
            )
    if report["accepted_manifest_rows"] != (
        report["unique_images"] + report["duplicate_rows_removed"]
    ):
        raise ExperimentConfigurationError(
            "build_report.json accepted/unique/duplicate counts are inconsistent."
        )
    if marker.get("unique_images") != report.get("unique_images"):
        raise ExperimentConfigurationError(
            "BUILD_COMPLETE.json unique_images differs from build_report.json."
        )
    class_summary = report.get("class_summary")
    if not isinstance(class_summary, dict) or set(class_summary) != set(classes):
        raise ExperimentConfigurationError(
            "build_report.json class_summary does not match class_order.json."
        )
    summary_image_count = 0
    summary_group_count = 0
    for class_name in classes:
        summary = class_summary[class_name]
        required_summary_fields = {"unique_images", "source_groups", "train", "val", "test"}
        if not isinstance(summary, dict) or set(summary) != required_summary_fields:
            raise ExperimentConfigurationError(
                f"build_report.json has an invalid class_summary for {class_name}."
            )
        if any(
            isinstance(summary[field], bool)
            or not isinstance(summary[field], int)
            or summary[field] < 0
            for field in required_summary_fields
        ):
            raise ExperimentConfigurationError(
                f"build_report.json has invalid counts for {class_name}."
            )
        if summary["unique_images"] != summary["train"] + summary["val"] + summary["test"]:
            raise ExperimentConfigurationError(
                f"build_report.json split counts are inconsistent for {class_name}."
            )
        summary_image_count += summary["unique_images"]
        summary_group_count += summary["source_groups"]
    if summary_image_count != report["unique_images"] or summary_group_count != report["source_groups"]:
        raise ExperimentConfigurationError(
            "build_report.json class totals are inconsistent."
        )

    input_policy = config.get("input_policy")
    if not isinstance(input_policy, dict):
        raise ExperimentConfigurationError("config_snapshot.json has no input_policy object.")
    approval_status = input_policy.get("required_approval_status")
    if approval_status != "approved":
        raise ExperimentConfigurationError(
            "Staged input policy must require approval_status=approved."
        )
    for required_flag in (
        "require_declared_sha256",
        "require_source_record",
        "require_rights_or_license",
    ):
        if input_policy.get(required_flag) is not True:
            raise ExperimentConfigurationError(
                f"Staged input policy must set {required_flag}=true."
            )
    split_policy = config.get("split")
    group_by = split_policy.get("group_by") if isinstance(split_policy, dict) else None
    if group_by != ["sha256", "source_record"]:
        raise ExperimentConfigurationError(
            "Staged split policy must group exactly by sha256 and source_record."
        )

    marker_hashes = marker.get("artifact_sha256")
    if not isinstance(marker_hashes, dict) or set(marker_hashes) != BUILDER_HASHED_ARTIFACTS:
        raise ExperimentConfigurationError(
            "BUILD_COMPLETE.json must hash the exact required builder artifacts."
        )
    for name in sorted(BUILDER_HASHED_ARTIFACTS):
        expected_hash = _validated_sha256(marker_hashes.get(name), context=f"BUILD_COMPLETE {name}")
        if file_sha256(root / name) != expected_hash:
            raise ExperimentConfigurationError(f"Builder artifact changed after completion: {name}")

    report_evidence = _normalized_input_manifest_evidence(
        report.get("input_manifests"), root, context="build_report.json"
    )
    config_evidence = _normalized_input_manifest_evidence(
        config.get("resolved_input_manifests"), root, context="config_snapshot.json"
    )
    marker_evidence = _normalized_input_manifest_evidence(
        marker.get("input_manifests"), root, context="BUILD_COMPLETE.json"
    )
    if report_evidence != config_evidence or report_evidence != marker_evidence:
        raise ExperimentConfigurationError(
            "Input manifest evidence differs across config, build report, and completion marker."
        )
    if marker.get("version") != report.get("version") or marker.get("built_at") != report.get("built_at"):
        raise ExperimentConfigurationError(
            "Build version/timestamp differs between report and completion marker."
        )
    if not isinstance(marker.get("version"), str) or not marker["version"].strip():
        raise ExperimentConfigurationError("Builder version must be a non-empty string.")
    if not isinstance(marker.get("built_at"), str) or not marker["built_at"].strip():
        raise ExperimentConfigurationError("Builder timestamp must be a non-empty string.")
    evidence_by_snapshot = {
        item["snapshot"]: {"sha256": item["sha256"], "source": item["source"]}
        for item in report_evidence
    }
    return approval_status.strip(), evidence_by_snapshot


def validate_staged_dataset_manifest(
    dataset_root: Path,
    *,
    approval_status: str,
    input_manifest_evidence: dict[str, dict[str, str]],
) -> int:
    """Require every staged image and its approval lineage to match builder evidence."""

    root = Path(dataset_root).expanduser().resolve()
    manifest_path = root / "dataset_manifest.csv"
    declared_paths: set[str] = set()
    declared_hashes: set[str] = set()
    sha_splits: dict[str, str] = {}
    group_splits: dict[str, str] = {}
    group_classes: dict[str, str] = {}
    group_hashes: dict[str, set[str]] = {}
    group_record_keys: dict[str, set[str]] = {}
    group_declared_keys: dict[str, list[str]] = {}
    source_key_owners: dict[str, tuple[str, str, str]] = {}
    manifest_class_counts: dict[str, dict[str, int]] = {}
    manifest_class_groups: dict[str, set[str]] = {}
    total_lineage_entries = 0
    snapshot_rows = _load_snapshot_rows(root, input_manifest_evidence)
    eligible_snapshot_identities: set[tuple[str, int]] = set()
    for snapshot, rows_by_number in snapshot_rows.items():
        for snapshot_row_number, snapshot_row in rows_by_number.items():
            approval_values = {
                str(snapshot_row.get(field) or "").strip().casefold()
                for field in ("review_status", "approval_status")
                if str(snapshot_row.get(field) or "").strip()
            }
            if len(approval_values) > 1:
                raise ExperimentConfigurationError(
                    f"Input snapshot {snapshot}:{snapshot_row_number} has conflicting approval fields."
                )
            if approval_values == {approval_status}:
                eligible_snapshot_identities.add((snapshot, snapshot_row_number))
    consumed_lineage_identities: set[tuple[str, int]] = set()
    try:
        with manifest_path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fieldnames = reader.fieldnames or []
            fields = set(fieldnames)
            missing_fields = sorted(STAGED_MANIFEST_FIELDS - fields)
            extra_fields = sorted(fields - STAGED_MANIFEST_FIELDS)
            if (
                missing_fields
                or extra_fields
                or len(fieldnames) != len(fields)
                or tuple(fieldnames) != STAGED_MANIFEST_COLUMNS
            ):
                raise ExperimentConfigurationError(
                    "Staged dataset manifest schema differs from the builder contract: "
                    f"missing={missing_fields or 'none'}; extra={extra_fields or 'none'}; "
                    f"duplicate_headers={len(fieldnames) != len(fields)}; "
                    f"ordered_schema={tuple(fieldnames) == STAGED_MANIFEST_COLUMNS}."
                )
            for row_number, row in enumerate(reader, start=2):
                staged_value = (row.get("staged_path") or "").strip()
                relative = PurePosixPath(staged_value)
                if (
                    not staged_value
                    or relative.is_absolute()
                    or len(relative.parts) != 3
                    or any(part in {"", ".", ".."} for part in relative.parts)
                ):
                    raise ExperimentConfigurationError(
                        f"Invalid staged_path at {manifest_path}:{row_number}: {staged_value!r}"
                    )
                normalized = relative.as_posix()
                if normalized in declared_paths:
                    raise ExperimentConfigurationError(
                        f"Duplicate staged_path in {manifest_path}: {normalized}"
                    )
                split, class_name, filename = relative.parts
                if split not in {"train", "val", "test"}:
                    raise ExperimentConfigurationError(
                        f"Invalid split in staged manifest row {row_number}: {split}"
                    )
                if (row.get("split") or "").strip() != split:
                    raise ExperimentConfigurationError(
                        f"Manifest split disagrees with staged_path at row {row_number}."
                    )
                if (row.get("class_name") or "").strip() != class_name:
                    raise ExperimentConfigurationError(
                        f"Manifest class_name disagrees with staged_path at row {row_number}."
                    )
                _, staged_file = _safe_relative_file(
                    root, normalized, context=f"dataset manifest row {row_number}"
                )
                if staged_file.suffix.lower() not in SUPPORTED_IMAGE_SUFFIXES:
                    raise ExperimentConfigurationError(
                        f"Manifest staged_path is not a torchvision image: {normalized}"
                    )
                digest = _validated_sha256(row.get("sha256"), context=f"manifest row {row_number}")
                if Path(filename).stem != digest or file_sha256(staged_file) != digest:
                    raise ExperimentConfigurationError(
                        f"Staged image name or content hash disagrees with manifest: {normalized}"
                    )
                if digest in declared_hashes:
                    raise ExperimentConfigurationError(
                        f"SHA-256 appears more than once in dataset_manifest.csv: {digest}"
                    )
                if row.get("approval_status", "").strip() != approval_status:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} is not explicitly {approval_status}."
                    )
                group_id = (row.get("group_id") or "").strip()
                if len(group_id) != 20 or any(
                    character not in "0123456789abcdef" for character in group_id
                ):
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} has an invalid group_id."
                    )
                try:
                    record_keys = json.loads(row.get("source_record_keys") or "")
                except json.JSONDecodeError as exc:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} has invalid source_record_keys."
                    ) from exc
                if (
                    not isinstance(record_keys, list)
                    or not record_keys
                    or not all(
                        isinstance(item, str) and item.strip() == item and item
                        for item in record_keys
                    )
                    or record_keys != sorted(set(record_keys))
                ):
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} has no valid source_record_keys."
                    )
                for field in (
                    "entry_id",
                    "source_file",
                    "source_manifest",
                    "source",
                    "source_record_id",
                    "rights_or_license",
                ):
                    if not (row.get(field) or "").strip():
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} has no {field}."
                        )
                snapshot = (row.get("source_manifest_snapshot") or "").strip()
                source_digest = _validated_sha256(
                    row.get("source_manifest_sha256"),
                    context=f"manifest source at row {row_number}",
                )
                evidence = input_manifest_evidence.get(snapshot)
                if evidence is None or evidence["sha256"] != source_digest:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} references unverified input evidence."
                    )
                if (row.get("source_manifest") or "").strip() != evidence["source"]:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} source_manifest differs from its snapshot."
                    )
                try:
                    source_row = int(row.get("source_manifest_row") or 0)
                    lineage = json.loads(row.get("lineage_json") or "")
                except (TypeError, ValueError, json.JSONDecodeError) as exc:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} has invalid source row or lineage."
                    ) from exc
                if source_row < 2 or not isinstance(lineage, list) or not lineage:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} has empty approval lineage."
                    )
                source_manifest_row = snapshot_rows.get(snapshot, {}).get(source_row)
                if source_manifest_row is None:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} references a missing snapshot row."
                    )
                representative = _snapshot_row_contract(
                    source_manifest_row,
                    row_number=source_row,
                    manifest_source=evidence["source"],
                )
                expected_representative = {
                    "approval_status": approval_status,
                    "class_name": class_name,
                    "entry_id": (row.get("entry_id") or "").strip(),
                    "source_file": (row.get("source_file") or "").strip(),
                    "source": (row.get("source") or "").strip(),
                    "source_record_id": (row.get("source_record_id") or "").strip(),
                    "source_record_url": (row.get("source_record_url") or "").strip(),
                    "source_image_url": (row.get("source_image_url") or "").strip(),
                    "rights_or_license": (row.get("rights_or_license") or "").strip(),
                    "reviewed_plant_part": (row.get("reviewed_plant_part") or "").strip(),
                    "sha256": digest,
                }
                for field, expected_value in expected_representative.items():
                    if representative.get(field) != expected_value:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} {field} differs from its approved "
                            "input snapshot row."
                        )
                lineage_fields = {
                    "entry_id",
                    "approval_status",
                    "source_file",
                    "source_manifest",
                    "source_manifest_sha256",
                    "source_manifest_snapshot",
                    "source_manifest_row",
                }
                representative_lineage = {
                    "entry_id": expected_representative["entry_id"],
                    "approval_status": approval_status,
                    "source_file": expected_representative["source_file"],
                    "source_manifest": evidence["source"],
                    "source_manifest_sha256": source_digest,
                    "source_manifest_snapshot": snapshot,
                    "source_manifest_row": source_row,
                }
                if representative_lineage not in lineage:
                    raise ExperimentConfigurationError(
                        f"Manifest row {row_number} representative is missing from lineage_json."
                    )
                total_lineage_entries += len(lineage)
                for lineage_index, lineage_item in enumerate(lineage):
                    if not isinstance(lineage_item, dict) or set(lineage_item) != lineage_fields:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} has incomplete lineage item {lineage_index}."
                        )
                    if lineage_item.get("approval_status") != approval_status:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} has unapproved lineage."
                        )
                    for field in ("entry_id", "source_file", "source_manifest"):
                        if not isinstance(lineage_item.get(field), str) or not lineage_item[field].strip():
                            raise ExperimentConfigurationError(
                                f"Manifest row {row_number} has invalid lineage {field}."
                            )
                    lineage_snapshot = lineage_item.get("source_manifest_snapshot")
                    lineage_digest = _validated_sha256(
                        lineage_item.get("source_manifest_sha256"),
                        context=f"manifest lineage at row {row_number}",
                    )
                    lineage_evidence = input_manifest_evidence.get(lineage_snapshot)
                    if (
                        lineage_evidence is None
                        or lineage_evidence["sha256"] != lineage_digest
                        or lineage_item.get("source_manifest") != lineage_evidence["source"]
                    ):
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} has unverified lineage evidence."
                        )
                    try:
                        lineage_row_number = int(lineage_item.get("source_manifest_row"))
                        if lineage_row_number < 2:
                            raise ValueError
                    except (TypeError, ValueError) as exc:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} has invalid lineage source row."
                        ) from exc
                    lineage_source_row = snapshot_rows.get(lineage_snapshot, {}).get(
                        lineage_row_number
                    )
                    if lineage_source_row is None:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} lineage references a missing snapshot row."
                        )
                    lineage_identity = (lineage_snapshot, lineage_row_number)
                    if lineage_identity in consumed_lineage_identities:
                        raise ExperimentConfigurationError(
                            "An approved input snapshot row appears more than once in "
                            f"lineage_json: {lineage_snapshot}:{lineage_row_number}"
                        )
                    consumed_lineage_identities.add(lineage_identity)
                    lineage_contract = _snapshot_row_contract(
                        lineage_source_row,
                        row_number=lineage_row_number,
                        manifest_source=lineage_evidence["source"],
                    )
                    for field in (
                        "entry_id",
                        "approval_status",
                        "source_file",
                    ):
                        if lineage_item.get(field) != lineage_contract.get(field):
                            raise ExperimentConfigurationError(
                                f"Manifest row {row_number} lineage {field} differs from "
                                "its approved input snapshot row."
                            )
                    if lineage_contract["class_name"] != class_name:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} lineage has a different class."
                        )
                    if lineage_contract["sha256"] != digest:
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} lineage has a different image hash."
                        )
                    if lineage_contract["rights_or_license"] == "":
                        raise ExperimentConfigurationError(
                            f"Manifest row {row_number} lineage has no rights or license."
                        )
                    group_record_keys.setdefault(group_id, set()).update(
                        lineage_contract["source_record_keys"]
                    )
                prior_sha_split = sha_splits.setdefault(digest, split)
                prior_group_split = group_splits.setdefault(group_id, split)
                if prior_sha_split != split:
                    raise ExperimentConfigurationError(
                        f"SHA-256 appears in multiple dataset splits: {digest}"
                    )
                if prior_group_split != split:
                    raise ExperimentConfigurationError(
                        f"Source group appears in multiple dataset splits: {group_id}"
                    )
                prior_group_class = group_classes.setdefault(group_id, class_name)
                if prior_group_class != class_name:
                    raise ExperimentConfigurationError(
                        f"Source group appears in multiple classes: {group_id}"
                    )
                if group_id in group_declared_keys and group_declared_keys[group_id] != record_keys:
                    raise ExperimentConfigurationError(
                        f"Source group has inconsistent source_record_keys: {group_id}"
                    )
                group_declared_keys[group_id] = record_keys
                group_hashes.setdefault(group_id, set()).add(digest)
                counts = manifest_class_counts.setdefault(
                    class_name, {"train": 0, "val": 0, "test": 0}
                )
                counts[split] += 1
                manifest_class_groups.setdefault(class_name, set()).add(group_id)
                declared_paths.add(normalized)
                declared_hashes.add(digest)
    except UnicodeDecodeError as exc:
        raise ExperimentConfigurationError(
            f"Staged dataset manifest is not valid UTF-8: {manifest_path}"
        ) from exc

    for group_id, hashes in group_hashes.items():
        observed_keys = sorted(group_record_keys.get(group_id, set()))
        declared_keys = group_declared_keys[group_id]
        if observed_keys != declared_keys:
            raise ExperimentConfigurationError(
                f"Source group {group_id} source_record_keys do not match approved lineage."
            )
        identity = "\n".join(
            [group_classes[group_id], *sorted(hashes), *observed_keys]
        )
        expected_group_id = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]
        if group_id != expected_group_id:
            raise ExperimentConfigurationError(
                f"Source group identifier does not match its approved lineage: {group_id}"
            )
        owner = (group_id, group_classes[group_id], group_splits[group_id])
        for source_key in observed_keys:
            previous_owner = source_key_owners.setdefault(source_key, owner)
            if previous_owner != owner:
                raise ExperimentConfigurationError(
                    "A source_record_key appears in multiple groups, classes, or splits: "
                    f"{source_key}"
                )

    actual_paths: set[str] = set()
    for split in ("train", "val", "test"):
        split_root = root / split
        for path in split_root.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if len(relative.parts) != 3:
                raise ExperimentConfigurationError(
                    f"Staged split contains a file outside split/class/file layout: {relative}"
                )
            if path.suffix.lower() not in SUPPORTED_IMAGE_SUFFIXES:
                raise ExperimentConfigurationError(
                    f"Staged split contains a non-torchvision image file: {relative}"
                )
            actual_paths.add(relative.as_posix())
    missing_from_manifest = sorted(actual_paths - declared_paths)
    missing_from_dataset = sorted(declared_paths - actual_paths)
    if missing_from_manifest or missing_from_dataset:
        raise ExperimentConfigurationError(
            "Staged dataset files do not match dataset_manifest.csv exactly. "
            f"unmanifested={missing_from_manifest or 'none'}; "
            f"missing={missing_from_dataset or 'none'}."
        )
    report = load_json_object(root / "build_report.json", description="dataset build report")
    if report["accepted_manifest_rows"] != total_lineage_entries:
        raise ExperimentConfigurationError(
            "build_report.json accepted_manifest_rows differs from total approval lineage."
        )
    if report["duplicate_rows_removed"] != total_lineage_entries - len(declared_paths):
        raise ExperimentConfigurationError(
            "build_report.json duplicate_rows_removed differs from approval lineage."
        )
    if consumed_lineage_identities != eligible_snapshot_identities:
        missing = sorted(eligible_snapshot_identities - consumed_lineage_identities)
        unexpected = sorted(consumed_lineage_identities - eligible_snapshot_identities)
        raise ExperimentConfigurationError(
            "Approval lineage does not cover every approved input snapshot row exactly once: "
            f"missing={missing or 'none'}; unexpected={unexpected or 'none'}."
        )
    class_summary = report["class_summary"]
    for class_name, summary in class_summary.items():
        observed = manifest_class_counts.get(
            class_name, {"train": 0, "val": 0, "test": 0}
        )
        if any(summary[split] != observed[split] for split in ("train", "val", "test")):
            raise ExperimentConfigurationError(
                f"build_report.json split counts differ from dataset_manifest.csv for {class_name}."
            )
        if summary["source_groups"] != len(manifest_class_groups.get(class_name, set())):
            raise ExperimentConfigurationError(
                f"build_report.json source group count differs for {class_name}."
            )
    return len(declared_paths)


def validate_dataset_class_order(
    dataset_root: Path,
    *,
    splits: Sequence[str],
    expected_class_order_path: Path | None = None,
    allow_legacy_dataset: bool = False,
) -> list[str]:
    root = reject_reparse_points(dataset_root)
    if not root.is_dir():
        raise FileNotFoundError(f"Dataset root not found: {root}")
    if not splits:
        raise ExperimentConfigurationError("At least one dataset split must be validated.")
    if (root / "BUILD_INCOMPLETE").exists():
        raise ExperimentConfigurationError(
            f"Dataset staging build is incomplete: {root / 'BUILD_INCOMPLETE'}"
        )

    reference_split = splits[0]
    class_order = _split_class_order(root / reference_split)
    for split in splits[1:]:
        split_order = _split_class_order(root / split)
        require_same_class_order(
            class_order,
            split_order,
            expected_name=f"dataset split {reference_split}",
            actual_name=f"dataset split {split}",
        )

    required_paths = [root / name for name in STAGED_DATASET_REQUIRED_FILES]
    present_count = sum(path.is_file() for path in required_paths)
    if present_count != len(required_paths):
        missing = [path.name for path in required_paths if not path.is_file()]
        if present_count:
            raise ExperimentConfigurationError(
                "Partial staged builder contract cannot be treated as legacy; missing: "
                + ", ".join(missing)
            )
        if not allow_legacy_dataset:
            raise ExperimentConfigurationError(
                "Dataset has no complete staged builder contract. Rebuild it with the staged "
                "builder or pass --allow-legacy-dataset explicitly for an eligible legacy run."
            )
        if len(class_order) == 29 or "unknown" in class_order:
            raise ExperimentConfigurationError(
                "Legacy dataset opt-in is forbidden for 29-class or unknown-class workflows."
            )
    else:
        declared_order = load_class_order(root / "class_order.json")
        require_same_class_order(
            declared_order,
            class_order,
            expected_name=str(root / "class_order.json"),
            actual_name=f"folder order under {root}",
        )
        approval_status, evidence = _validate_builder_contract(root, declared_order)
        manifested_count = validate_staged_dataset_manifest(
            root,
            approval_status=approval_status,
            input_manifest_evidence=evidence,
        )
        marker = load_json_object(root / "BUILD_COMPLETE.json", description="dataset completion marker")
        report = load_json_object(root / "build_report.json", description="dataset build report")
        if marker.get("unique_images") != manifested_count or report.get("unique_images") != manifested_count:
            raise ExperimentConfigurationError(
                "Builder image counts do not match dataset_manifest.csv."
            )

    if expected_class_order_path is not None:
        explicit_path = Path(expected_class_order_path).expanduser().resolve()
        expected_order = load_class_order(explicit_path)
        require_same_class_order(
            expected_order,
            class_order,
            expected_name=str(explicit_path),
            actual_name=f"folder order under {root}",
        )
    return class_order


def checkpoint_class_order(checkpoint: object) -> list[str]:
    if not isinstance(checkpoint, dict):
        raise ExperimentConfigurationError(
            "Checkpoint must be a dictionary containing model_state_dict and classes."
        )
    classes = checkpoint.get("classes")
    if not isinstance(classes, list) or not classes or not all(
        isinstance(item, str) and item and item.strip() == item for item in classes
    ):
        raise ExperimentConfigurationError(
            "Checkpoint does not contain a valid non-empty classes list."
        )
    if len(set(classes)) != len(classes):
        raise ExperimentConfigurationError("Checkpoint classes contain duplicate labels.")
    return list(classes)


def validate_checkpoint_class_order(checkpoint: object, classes: Sequence[str]) -> None:
    embedded = checkpoint_class_order(checkpoint)
    require_same_class_order(
        list(classes),
        embedded,
        expected_name="class_order.json",
        actual_name="checkpoint classes",
    )


def validate_checkpoint_image_size(checkpoint: object) -> int:
    if not isinstance(checkpoint, dict):
        raise ExperimentConfigurationError(
            "Checkpoint must be a dictionary containing image_size."
        )
    image_size = checkpoint.get("image_size")
    if isinstance(image_size, bool) or not isinstance(image_size, int):
        raise ExperimentConfigurationError(
            "Checkpoint does not contain an integer image_size."
        )
    if image_size != RUNTIME_IMAGE_SIZE:
        raise ExperimentConfigurationError(
            "Checkpoint image_size is incompatible with the server and Flutter runtimes: "
            f"expected={RUNTIME_IMAGE_SIZE}, checkpoint={image_size}."
        )
    return image_size


def replace_artifact_pair_with_rollback(
    *,
    first_source: Path,
    second_source: Path,
    first_target: Path,
    second_target: Path,
    copy_file=shutil.copy2,
    replace_file=os.replace,
    cleanup_file=None,
    expected_first_sha256: str | None = None,
    expected_second_sha256: str | None = None,
) -> tuple[Path, Path]:
    """Replace a related pair under one lock and restore verified originals on failure."""

    raw_sources = (Path(first_source).expanduser().absolute(), Path(second_source).expanduser().absolute())
    raw_targets = (Path(first_target).expanduser().absolute(), Path(second_target).expanduser().absolute())
    for source in raw_sources:
        if not source.is_file():
            raise FileNotFoundError(f"Promotion source file not found: {source}")
        if _is_reparse_point(source):
            raise ExperimentConfigurationError(
                f"Promotion source cannot be a symlink or reparse point: {source}"
            )
    sources = tuple(source.resolve() for source in raw_sources)
    if sources[0] == sources[1]:
        raise ExperimentConfigurationError("Paired promotion sources must be different files.")
    if raw_targets[0] == raw_targets[1] or raw_targets[0].name == raw_targets[1].name:
        raise ExperimentConfigurationError("Paired promotion targets must be different files.")
    if raw_targets[0].parent != raw_targets[1].parent:
        raise ExperimentConfigurationError(
            "Paired promotion targets must share the same destination directory."
        )

    raw_destination = raw_targets[0].parent
    for component in (raw_destination, *raw_destination.parents):
        if component.exists() and _is_reparse_point(component):
            raise ExperimentConfigurationError(
                "Promotion destination cannot pass through a symlink or reparse point: "
                f"{component}"
            )
    raw_destination.mkdir(parents=True, exist_ok=True)
    destination = raw_destination.resolve()
    targets = tuple(destination / target.name for target in raw_targets)
    for target in targets:
        if target.exists() and _is_reparse_point(target):
            raise ExperimentConfigurationError(
                f"Promotion target cannot be a symlink or reparse point: {target}"
            )
        if target.resolve() != target or target.parent != destination:
            raise ExperimentConfigurationError(
                f"Promotion target resolves outside its destination: {target}"
            )
        for source in sources:
            if target == source or (target.exists() and os.path.samefile(target, source)):
                raise ExperimentConfigurationError(
                    f"Promotion source and target cannot alias the same file: {target}"
                )

    supplied_hashes = (expected_first_sha256, expected_second_sha256)
    expected_hashes: list[str] = []
    for index, (source, supplied) in enumerate(zip(sources, supplied_hashes), start=1):
        expected = (
            _validated_sha256(supplied, context=f"promotion source {index}")
            if supplied is not None
            else file_sha256(source)
        )
        if file_sha256(source) != expected:
            raise ExperimentConfigurationError(
                f"Promotion source changed or does not match its recorded hash: {source}"
            )
        expected_hashes.append(expected)

    destination.mkdir(parents=True, exist_ok=True)
    transaction_id = uuid.uuid4().hex
    temporary = tuple(
        destination / f".{target.name}.{transaction_id}.tmp" for target in targets
    )
    backups = tuple(
        destination / f".{target.name}.{transaction_id}.bak" for target in targets
    )
    lock_path = destination / ".artifact-promotion.lock"
    journal_path = destination / f".artifact-promotion-{transaction_id}.json"
    had_original = (False, False)
    original_hashes: tuple[str | None, str | None] = (None, None)
    backup_created = [False, False]
    installed_new = [False, False]
    promotion_succeeded = False
    rollback_complete = False
    lock_acquired = False

    def best_effort_cleanup(path: Path) -> bool:
        try:
            if cleanup_file is None:
                path.unlink(missing_ok=True)
            else:
                cleanup_file(path)
            return True
        except BaseException as exc:
            # A successfully installed pair remains successful. Stale transaction files
            # are recoverable and must not make callers report that active assets failed.
            try:
                warnings.warn(
                    f"Artifact promotion cleanup could not remove {path}: {exc}",
                    RuntimeWarning,
                    stacklevel=2,
                )
            except BaseException:
                pass
            return False

    try:
        try:
            lock_fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as exc:
            raise ExperimentConfigurationError(
                f"Another artifact promotion or an unrecovered transaction holds {lock_path}."
            ) from exc
        lock_acquired = True
        had_original = tuple(target.is_file() for target in targets)
        original_hashes = tuple(
            file_sha256(target) if exists else None
            for target, exists in zip(targets, had_original)
        )
        with os.fdopen(lock_fd, "w", encoding="utf-8") as lock_handle:
            lock_handle.write(transaction_id + "\n")
            lock_handle.flush()
            os.fsync(lock_handle.fileno())
        journal = {
            "schema_version": 1,
            "transaction_id": transaction_id,
            "status": "prepared",
            "sources": [str(path) for path in sources],
            "targets": [str(path) for path in targets],
            "backups": [str(path) for path in backups],
            "expected_sha256": expected_hashes,
            "original_sha256": list(original_hashes),
        }
        write_json(journal, journal_path)
        copy_file(sources[0], temporary[0])
        copy_file(sources[1], temporary[1])
        for source, staged_copy, expected in zip(sources, temporary, expected_hashes):
            if file_sha256(source) != expected or file_sha256(staged_copy) != expected:
                raise ExperimentConfigurationError(
                    f"Promotion staging copy failed hash verification: {source}"
                )
        for index, target in enumerate(targets):
            if had_original[index]:
                copy_file(target, backups[index])
                if file_sha256(backups[index]) != original_hashes[index]:
                    raise ExperimentConfigurationError(
                        f"Promotion backup failed hash verification: {target}"
                    )
                backup_created[index] = True
        journal["status"] = "backed_up"
        write_json(journal, journal_path)
        for index, target in enumerate(targets):
            replace_file(temporary[index], target)
            installed_new[index] = True
            journal["status"] = f"installed_{index + 1}"
            write_json(journal, journal_path)
        for source, target, expected in zip(sources, targets, expected_hashes):
            if file_sha256(source) != expected or file_sha256(target) != expected:
                raise ExperimentConfigurationError(
                    f"Installed promotion artifact failed hash verification: {target}"
                )
        journal["status"] = "installed"
        write_json(journal, journal_path)
        promotion_succeeded = True
    except BaseException as promotion_error:
        if not lock_acquired:
            raise
        rollback_errors: list[str] = []
        for index, target in reversed(tuple(enumerate(targets))):
            if had_original[index] and backup_created[index] and backups[index].exists():
                try:
                    replace_file(backups[index], target)
                except BaseException as exc:
                    rollback_errors.append(f"restore {target}: {exc}")
            elif not had_original[index] and target.exists():
                try:
                    target.unlink(missing_ok=True)
                except BaseException as exc:
                    rollback_errors.append(f"remove {target}: {exc}")
        for index, target in enumerate(targets):
            try:
                if had_original[index]:
                    if not target.is_file() or file_sha256(target) != original_hashes[index]:
                        rollback_errors.append(f"verify restored target {target}")
                elif target.exists():
                    rollback_errors.append(f"verify absent target {target}")
            except BaseException as exc:
                rollback_errors.append(f"verify {target}: {exc}")
        rollback_complete = not rollback_errors
        if rollback_errors:
            raise ExperimentConfigurationError(
                "Artifact promotion failed and rollback was incomplete. Backup files were "
                f"preserved for recovery: {[path for path in backups if path.exists()]}. "
                f"Errors: {rollback_errors}"
            ) from promotion_error
        raise
    finally:
        for path in temporary:
            best_effort_cleanup(path)
        if promotion_succeeded:
            backup_cleanup_results = [best_effort_cleanup(path) for path in backups]
            backups_cleaned = all(backup_cleanup_results)
            if backups_cleaned:
                best_effort_cleanup(journal_path)
        elif rollback_complete:
            for path in backups:
                best_effort_cleanup(path)
            best_effort_cleanup(journal_path)
        if lock_acquired and (promotion_succeeded or rollback_complete):
            best_effort_cleanup(lock_path)

    return targets


def promote_checkpoint_bundle(
    *,
    source_checkpoint: Path,
    source_class_order: Path,
    destination_dir: Path = ACTIVE_SERVER_MODEL_DIR,
    copy_file=shutil.copy2,
    replace_file=os.replace,
    cleanup_file=None,
    expected_checkpoint_sha256: str | None = None,
    expected_class_order_sha256: str | None = None,
) -> tuple[Path, Path]:
    load_class_order(source_class_order)
    destination = Path(destination_dir).expanduser().resolve()
    return replace_artifact_pair_with_rollback(
        first_source=source_checkpoint,
        second_source=source_class_order,
        first_target=destination / "efficientnet_b0_best.pth",
        second_target=destination / "class_order.json",
        copy_file=copy_file,
        replace_file=replace_file,
        cleanup_file=cleanup_file,
        expected_first_sha256=expected_checkpoint_sha256,
        expected_second_sha256=expected_class_order_sha256,
    )


def promote_onnx_bundle(
    *,
    source_model: Path,
    source_class_order: Path,
    destination_dir: Path = ACTIVE_FLUTTER_MODEL_DIR,
    model_filename: str = PREFERRED_FLUTTER_MODEL_FILENAME,
    copy_file=shutil.copy2,
    replace_file=os.replace,
    cleanup_file=None,
    expected_model_sha256: str | None = None,
    expected_class_order_sha256: str | None = None,
) -> tuple[Path, Path]:
    """Copy a validated ONNX/label pair only after an explicit promotion request."""

    source_model = Path(source_model).resolve()
    source_class_order = Path(source_class_order).resolve()
    if not source_model.is_file():
        raise FileNotFoundError(f"Staged ONNX model not found: {source_model}")
    classes = load_class_order(source_class_order)
    if not classes:
        raise ExperimentConfigurationError("Cannot promote an empty class order.")

    destination = Path(destination_dir).expanduser().resolve()
    model_target = destination / model_filename
    labels_target = destination / "class_order.json"
    return replace_artifact_pair_with_rollback(
        first_source=source_model,
        second_source=source_class_order,
        first_target=model_target,
        second_target=labels_target,
        copy_file=copy_file,
        replace_file=replace_file,
        cleanup_file=cleanup_file,
        expected_first_sha256=expected_model_sha256,
        expected_second_sha256=expected_class_order_sha256,
    )
