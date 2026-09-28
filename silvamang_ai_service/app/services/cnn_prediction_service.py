from __future__ import annotations

import json
import hashlib
import os
from io import BytesIO
from pathlib import Path


class CNNPredictionService:
    RUNTIME_IMAGE_SIZE = 224
    RUNTIME_RESIZE_SIZE = 256
    LEGACY_CLASS_ALIASES = {
        "Avicennia_marina_var_rumphiana": "Avicennia_rumphiana",
        "Xylocarpus_rumphii": "Xylocarpus_moluccensis",
    }

    def __init__(self) -> None:
        self.service_root = Path(__file__).resolve().parents[2]
        self.project_root = self.service_root.parent
        self.model_path = self._resolve_path(
            "CNN_MODEL_PATH",
            self.service_root / "models" / "EfficientNet-B0" / "efficientnet_b0_runtime.pth",
        )
        self.class_order_path = self._resolve_path(
            "CNN_CLASS_ORDER_PATH",
            self.model_path.parent / "class_order.json",
        )
        self.image_size = self.RUNTIME_IMAGE_SIZE
        self._model = None
        self._classes: list[str] | None = None
        self._load_error: str | None = None
        self._checkpoint_sha256: str | None = None
        self._class_order_sha256: str | None = None

    def is_available(self) -> bool:
        if not self.model_path.exists():
            self._load_error = f"Model file not found: {self.model_path}"
            return False

        try:
            self._dependencies()
            self._load_model()
            return True
        except Exception as exc:
            self._load_error = str(exc)
            return False

    def class_count(self) -> int:
        return len(self._load_classes())

    def class_order(self) -> list[str]:
        return self._load_classes()

    def load_error(self) -> str | None:
        return self._load_error

    def readiness(self) -> dict:
        available = self.is_available()

        return {
            "available": available,
            "model_path": str(self.model_path),
            "model_file": self.model_path.name,
            "class_order_path": str(self.class_order_path),
            "class_order_file": self.class_order_path.name,
            "class_count": self.class_count() if available else 0,
            "required_image_size": self.RUNTIME_IMAGE_SIZE,
            "loaded_image_size": self.image_size if available else None,
            "checkpoint_sha256": self._checkpoint_sha256 if available else None,
            "class_order_sha256": self._class_order_sha256 if available else None,
            "required_dependencies": ["torch", "torchvision", "pillow"],
            "load_error": self.load_error(),
        }

    def predict_image(self, image_bytes: bytes, top_k: int = 3) -> dict:
        torch, Image, transforms, _ = self._dependencies()
        classes = self._load_classes()
        model = self._load_model()
        model_name = "SILVAMANG EfficientNet-B0"
        model_version = f"efficientnet-b0-{self._checkpoint_sha256[:12]}"

        image = Image.open(BytesIO(image_bytes)).convert("RGB")
        tensor = self._preprocess(image, transforms).unsqueeze(0)

        model.eval()
        with torch.no_grad():
            outputs = model(tensor)
            probabilities = torch.softmax(outputs, dim=1)
            scores, indices = probabilities.topk(min(top_k, len(classes)), dim=1)

        predictions = []
        for rank, (score, index) in enumerate(zip(scores[0], indices[0]), start=1):
            class_index = index.item()
            predictions.append(
                {
                    "rank": rank,
                    "species_id": None,
                    "scientific_name": classes[class_index],
                    "common_name": None,
                    "confidence": round(score.item() * 100, 2),
                    "model_name": model_name,
                    "model_version": model_version,
                }
            )

        top_prediction = predictions[0]
        predicted_class_index = indices[0][0].item()

        return {
            "mode": "cnn_efficientnet_b0",
            "source": "python_ai_service",
            "model": {
                "name": model_name,
                "version": model_version,
                "type": "classification",
            },
            "top_prediction": {
                "species_id": top_prediction["species_id"],
                "scientific_name": top_prediction["scientific_name"],
                "common_name": top_prediction["common_name"],
                "confidence": top_prediction["confidence"],
            },
            "predictions": predictions,
            "explanation": "Prediction generated using the trained SILVAMANG EfficientNet-B0 transfer-learning model.",
            "measurement": {
                "height_m": None,
                "canopy_width_m": None,
                "dbh_cm": None,
                "measurement_method": "not_estimated",
                "confidence": None,
            },
            "location_hint": {
                "latitude": None,
                "longitude": None,
                "message": "Location validation should be completed by the Laravel backend.",
            },
            "received": {
                "plant_parts": [],
                "image_count": 1,
            },
            "debug": {
                "class_order": classes,
                "predicted_class_index": predicted_class_index,
            },
        }

    def _dependencies(self):
        try:
            import torch
            from PIL import Image
            from torchvision import models, transforms
        except Exception as exc:
            raise RuntimeError(f"CNN dependencies unavailable: {exc}") from exc

        return torch, Image, transforms, models

    def _resolve_path(self, env_key: str, fallback: Path) -> Path:
        configured_path = os.getenv(env_key)
        if not configured_path:
            return fallback

        path = Path(configured_path)
        return path if path.is_absolute() else self.service_root / path

    def _load_model(self):
        if self._model is not None:
            return self._model

        torch, _, _, models = self._dependencies()
        classes = self._load_classes()
        checkpoint = torch.load(self.model_path, map_location="cpu")
        if not isinstance(checkpoint, dict):
            raise ValueError(
                "CNN checkpoint must include model_state_dict, classes, and image_size metadata."
            )
        state_dict = checkpoint.get("model_state_dict")
        if not isinstance(state_dict, dict):
            raise ValueError("CNN checkpoint does not contain model_state_dict.")
        checkpoint_classes = checkpoint.get("classes")
        if not isinstance(checkpoint_classes, list) or not all(
            isinstance(item, str) for item in checkpoint_classes
        ):
            raise ValueError("CNN checkpoint does not contain a valid classes list.")
        normalized_checkpoint_classes = [
            self.LEGACY_CLASS_ALIASES.get(item, item) for item in checkpoint_classes
        ]
        if normalized_checkpoint_classes != classes:
            raise ValueError(
                "CNN checkpoint classes do not match class_order.json after approved legacy "
                "alias normalization. "
                "Deploy the checkpoint and labels as one evaluated bundle."
            )
        checkpoint_image_size = checkpoint.get("image_size")
        if checkpoint_image_size != self.RUNTIME_IMAGE_SIZE:
            raise ValueError(
                "CNN checkpoint image_size is incompatible with runtime preprocessing: "
                f"expected={self.RUNTIME_IMAGE_SIZE}, checkpoint={checkpoint_image_size!r}."
            )
        if checkpoint.get("model_name", "efficientnet_b0") != "efficientnet_b0":
            raise ValueError("CNN checkpoint model_name must be efficientnet_b0.")
        model = models.efficientnet_b0(weights=None)
        in_features = model.classifier[1].in_features
        model.classifier[1] = torch.nn.Linear(in_features, len(classes))
        if model.classifier[1].out_features != len(classes):
            raise ValueError("CNN output count does not match class_order.json.")
        model.load_state_dict(state_dict)
        model.eval()
        self._model = model
        self._checkpoint_sha256 = self._file_sha256(self.model_path)
        self._class_order_sha256 = self._file_sha256(self.class_order_path)

        return self._model

    def _load_classes(self) -> list[str]:
        if self._classes is not None:
            return self._classes

        if not self.class_order_path.exists():
            raise FileNotFoundError(f"Class order file not found: {self.class_order_path}")

        classes = json.loads(self.class_order_path.read_text(encoding="utf-8"))
        if (
            not isinstance(classes, list)
            or not classes
            or not all(
                isinstance(item, str) and item and item.strip() == item
                for item in classes
            )
            or len(set(classes)) != len(classes)
        ):
            raise ValueError("class_order.json must contain a non-empty list of class names.")

        self._classes = classes
        return self._classes

    def _preprocess(self, image, transforms):
        transform = transforms.Compose(
            [
                transforms.Resize(self.RUNTIME_RESIZE_SIZE),
                transforms.CenterCrop(self.image_size),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225],
                ),
            ]
        )

        return transform(image)

    @staticmethod
    def _file_sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
