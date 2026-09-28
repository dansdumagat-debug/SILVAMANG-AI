from __future__ import annotations

import hashlib
import json
import shutil
import uuid
from pathlib import Path
from types import SimpleNamespace

import pytest

from app.services.cnn_prediction_service import CNNPredictionService


@pytest.fixture
def scratch_path() -> Path:
    test_root = Path(__file__).resolve().parent / ".test-artifacts"
    test_root.mkdir(exist_ok=True)
    directory = test_root / f"cnn-runtime-{uuid.uuid4().hex}"
    directory.mkdir()
    try:
        yield directory
    finally:
        shutil.rmtree(directory, ignore_errors=True)


class _FakeModel:
    def __init__(self) -> None:
        self.classifier = [None, SimpleNamespace(in_features=4)]
        self.loaded_state = None

    def load_state_dict(self, state_dict) -> None:
        self.loaded_state = state_dict

    def eval(self) -> None:
        return None


class _FakeModels:
    @staticmethod
    def efficientnet_b0(*, weights=None) -> _FakeModel:
        return _FakeModel()


class _FakeLinear:
    def __init__(self, in_features: int, out_features: int) -> None:
        self.in_features = in_features
        self.out_features = out_features


class _FakeTorch:
    def __init__(self, checkpoint: object) -> None:
        self.checkpoint = checkpoint
        self.nn = SimpleNamespace(Linear=_FakeLinear)

    def load(self, path: Path, *, map_location: str) -> object:
        return self.checkpoint


def _service(tmp_path: Path, checkpoint: object, classes: list[str]) -> CNNPredictionService:
    model_path = tmp_path / "efficientnet_b0_best.pth"
    class_order_path = tmp_path / "class_order.json"
    model_path.write_bytes(b"checkpoint bytes")
    class_order_path.write_text(json.dumps(classes), encoding="utf-8")

    service = CNNPredictionService()
    service.model_path = model_path
    service.class_order_path = class_order_path
    fake_torch = _FakeTorch(checkpoint)
    service._dependencies = lambda: (fake_torch, object(), object(), _FakeModels())
    return service


@pytest.mark.parametrize("image_size", [None, 223, 225])
def test_runtime_rejects_checkpoint_with_non_224_input(
    scratch_path: Path,
    image_size: int | None,
) -> None:
    classes = ["Species_alpha", "unknown"]
    service = _service(
        scratch_path,
        {
            "model_name": "efficientnet_b0",
            "model_state_dict": {"weights": "fake"},
            "classes": classes,
            "image_size": image_size,
        },
        classes,
    )

    assert service.is_available() is False
    assert "image_size" in (service.load_error() or "")


def test_runtime_rejects_checkpoint_class_order_mismatch(scratch_path: Path) -> None:
    service = _service(
        scratch_path,
        {
            "model_name": "efficientnet_b0",
            "model_state_dict": {"weights": "fake"},
            "classes": ["unknown", "Species_alpha"],
            "image_size": 224,
        },
        ["Species_alpha", "unknown"],
    )

    assert service.is_available() is False
    assert "do not match" in (service.load_error() or "")


@pytest.mark.parametrize(
    ("legacy_label", "canonical_label"),
    [
        ("Avicennia_marina_var_rumphiana", "Avicennia_rumphiana"),
        ("Xylocarpus_rumphii", "Xylocarpus_moluccensis"),
    ],
)
def test_runtime_accepts_only_approved_legacy_checkpoint_aliases(
    scratch_path: Path,
    legacy_label: str,
    canonical_label: str,
) -> None:
    service = _service(
        scratch_path,
        {
            "model_name": "efficientnet_b0",
            "model_state_dict": {"weights": "fake"},
            "classes": [legacy_label, "unknown"],
            "image_size": 224,
        },
        [canonical_label, "unknown"],
    )

    assert service.is_available() is True


def test_readiness_reports_loaded_224_contract_and_artifact_hashes(
    scratch_path: Path,
) -> None:
    classes = ["Species_alpha", "unknown"]
    service = _service(
        scratch_path,
        {
            "model_name": "efficientnet_b0",
            "model_state_dict": {"weights": "fake"},
            "classes": classes,
            "image_size": 224,
        },
        classes,
    )

    readiness = service.readiness()

    assert readiness["available"] is True
    assert readiness["class_count"] == 2
    assert readiness["required_image_size"] == 224
    assert readiness["loaded_image_size"] == 224
    assert readiness["checkpoint_sha256"] == hashlib.sha256(b"checkpoint bytes").hexdigest()
    assert readiness["class_order_sha256"]
