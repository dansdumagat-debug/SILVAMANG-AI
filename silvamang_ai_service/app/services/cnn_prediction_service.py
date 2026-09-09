from __future__ import annotations

import json
import os
from io import BytesIO
from pathlib import Path


class CNNPredictionService:
    def __init__(self) -> None:
        self.service_root = Path(__file__).resolve().parents[2]
        self.project_root = self.service_root.parent
        self.model_path = self._resolve_path(
            "CNN_MODEL_PATH",
            self.service_root / "models" / "cnn_classifier" / "efficientnet_b0_best.pth",
        )
        self.class_order_path = self._resolve_path(
            "CNN_CLASS_ORDER_PATH",
            self.service_root / "models" / "cnn_classifier" / "class_order.json",
        )
        self.image_size = 224
        self._model = None
        self._classes: list[str] | None = None
        self._load_error: str | None = None

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
            "required_dependencies": ["torch", "torchvision", "pillow"],
            "load_error": self.load_error(),
        }

    def predict_image(self, image_bytes: bytes, top_k: int = 3) -> dict:
        torch, Image, transforms, _ = self._dependencies()
        classes = self._load_classes()
        model = self._load_model()
        model_name = "SILVAMANG EfficientNet-B0"
        model_version = "transfer-learning-0.1.0"

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
        state_dict = checkpoint.get("model_state_dict", checkpoint) if isinstance(checkpoint, dict) else checkpoint
        model = models.efficientnet_b0(weights=None)
        in_features = model.classifier[1].in_features
        model.classifier[1] = torch.nn.Linear(in_features, len(classes))
        model.load_state_dict(state_dict)
        model.eval()
        self._model = model

        return self._model

    def _load_classes(self) -> list[str]:
        if self._classes is not None:
            return self._classes

        if not self.class_order_path.exists():
            raise FileNotFoundError(f"Class order file not found: {self.class_order_path}")

        classes = json.loads(self.class_order_path.read_text(encoding="utf-8"))
        if not isinstance(classes, list) or not all(isinstance(item, str) and item.strip() for item in classes):
            raise ValueError("class_order.json must contain a non-empty list of class names.")

        self._classes = classes
        return self._classes

    def _preprocess(self, image, transforms):
        transform = transforms.Compose(
            [
                transforms.Resize(int(self.image_size * 1.15)),
                transforms.CenterCrop(self.image_size),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225],
                ),
            ]
        )

        return transform(image)
