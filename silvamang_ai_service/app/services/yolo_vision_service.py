from __future__ import annotations

import base64
import os
from io import BytesIO
from pathlib import Path
from typing import Any


class YOLOVisionService:
    def __init__(self, task: str) -> None:
        self.task = task
        self.service_root = Path(__file__).resolve().parents[2]
        self.model_path = self._resolve_model_path()
        self._model = None
        self._load_error: str | None = None

    def is_available(self) -> bool:
        if self.model_path is None or not self.model_path.exists():
            self._load_error = f"{self.task} model file not found"
            return False

        try:
            self._load_model()
            return True
        except Exception as exc:
            self._load_error = str(exc)
            return False

    def version(self) -> str | None:
        return self.model_path.name if self.model_path else None

    def load_error(self) -> str | None:
        return self._load_error

    def readiness(self) -> dict[str, Any]:
        available = self.is_available()

        return {
            "available": available,
            "task": self.task,
            "model_path": str(self.model_path) if self.model_path else None,
            "model_file": self.model_path.name if self.model_path else None,
            "expected_locations": [str(path) for path in self.expected_model_locations()],
            "required_dependency": "ultralytics",
            "load_error": self.load_error(),
        }

    def detect(self, image_bytes: bytes) -> list[dict[str, Any]]:
        result = self._predict_result(image_bytes)
        boxes = getattr(result, "boxes", None)
        if boxes is None:
            return []

        names = getattr(result, "names", None) or getattr(self._model, "names", {})
        xyxy = boxes.xyxy.detach().cpu().tolist()
        confidences = boxes.conf.detach().cpu().tolist()
        classes = boxes.cls.detach().cpu().tolist()

        detections = []
        for bbox, confidence, class_index in zip(xyxy, confidences, classes):
            label = self._label_for_index(names, int(class_index))
            detections.append(
                {
                    "class": label,
                    "confidence": round(float(confidence) * 100, 2),
                    "bbox": [round(float(value), 2) for value in bbox],
                }
            )

        return detections

    def segment(self, image_bytes: bytes) -> dict[str, Any]:
        result = self._predict_result(image_bytes)
        masks = getattr(result, "masks", None)
        if masks is None or getattr(masks, "data", None) is None:
            return {
                "mask": "",
                "area_pixels": 0,
            }

        mask = masks.data[0].detach().cpu().numpy()
        binary_mask = mask > 0.5
        area_pixels = int(binary_mask.sum())

        from PIL import Image

        mask_image = Image.fromarray((binary_mask * 255).astype("uint8"), mode="L")
        buffer = BytesIO()
        mask_image.save(buffer, format="PNG")

        return {
            "mask": base64.b64encode(buffer.getvalue()).decode("ascii"),
            "area_pixels": area_pixels,
        }

    def _predict_result(self, image_bytes: bytes):
        model = self._load_model()

        from PIL import Image

        image = Image.open(BytesIO(image_bytes)).convert("RGB")
        results = model(image, device="cpu", verbose=False)
        if not results:
            raise RuntimeError("YOLO inference returned no result")

        return results[0]

    def _load_model(self):
        if self._model is not None:
            return self._model

        if self.model_path is None:
            raise FileNotFoundError(f"{self.task} model file not found")

        try:
            from ultralytics import YOLO
        except Exception as exc:
            raise RuntimeError(f"ultralytics package unavailable: {exc}") from exc

        self._model = YOLO(str(self.model_path))
        return self._model

    def _resolve_model_path(self) -> Path | None:
        env_key = "YOLO_DETECTOR_MODEL_PATH"
        folders = [
            "models/yolo_detector",
            "models/yolo_detection",
            "models/yolo",
        ]

        if self.task == "segmentation":
            env_key = "YOLO_SEGMENTATION_MODEL_PATH"
            folders = [
                "models/yolo_segmenter",
                "models/yolo_segmentation",
                "models/yolo_segment",
                "models/yolo",
            ]

        configured_path = os.getenv(env_key)
        if configured_path:
            path = Path(configured_path)
            if not path.is_absolute():
                path = self.service_root / path
            if path.exists():
                return path

        for folder in folders:
            directory = self.service_root / folder
            if not directory.exists():
                continue

            for pattern in ("best.pt", "*.pt", "*.onnx"):
                matches = sorted(directory.glob(pattern))
                if matches:
                    return matches[0]

        return None

    def expected_model_locations(self) -> list[Path]:
        if self.task == "segmentation":
            folders = [
                "models/yolo_segmenter",
                "models/yolo_segmentation",
                "models/yolo_segment",
                "models/yolo",
            ]
        else:
            folders = [
                "models/yolo_detector",
                "models/yolo_detection",
                "models/yolo",
            ]

        return [self.service_root / folder / "best.pt" for folder in folders]

    def _label_for_index(self, names, index: int) -> str:
        if isinstance(names, dict):
            return str(names.get(index, index))

        if isinstance(names, list) and 0 <= index < len(names):
            return str(names[index])

        return str(index)
