from __future__ import annotations

import io
import math
import os
from pathlib import Path

from PIL import Image


class MidasMeasurementService:
    def __init__(self) -> None:
        self.service_root = Path(__file__).resolve().parents[2]
        self.model_path = self._resolve_model_path()
        self._model = None
        self._load_error: str | None = None

    def is_available(self) -> bool:
        if self.model_path is None or not self.model_path.exists():
            self._load_error = "MiDaS model file not found"
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

    def readiness(self) -> dict:
        available = self.is_available()

        return {
            "available": available,
            "model_path": str(self.model_path) if self.model_path else None,
            "model_file": self.model_path.name if self.model_path else None,
            "expected_locations": [str(path) for path in self.expected_model_locations()],
            "required_dependency": "torch",
            "metric_measurement_requires": [
                "known camera-to-tree distance",
                "ARCore/depth scale",
                "or calibrated reference object",
            ],
            "load_error": self.load_error(),
        }

    def measure(
        self,
        image_bytes: bytes,
        *,
        measurement_type: str | None = None,
        reference_height_m: float | None = None,
        subject_distance_m: float | None = None,
        reference_distance_m: float | None = None,
        subject_pixel_span: float | None = None,
        reference_pixel_span: float | None = None,
        subject_point_a_x: float | None = None,
        subject_point_a_y: float | None = None,
        subject_point_b_x: float | None = None,
        subject_point_b_y: float | None = None,
        reference_point_a_x: float | None = None,
        reference_point_a_y: float | None = None,
        reference_point_b_x: float | None = None,
        reference_point_b_y: float | None = None,
    ) -> dict:
        if not image_bytes:
            raise ValueError("No image bytes received")

        image_width, image_height = self._image_dimensions(image_bytes)
        subject_span_px = self._resolved_pixel_span(
            explicit_span=subject_pixel_span,
            point_a_x=subject_point_a_x,
            point_a_y=subject_point_a_y,
            point_b_x=subject_point_b_x,
            point_b_y=subject_point_b_y,
            image_width=image_width,
            image_height=image_height,
        )
        reference_span_px = self._resolved_pixel_span(
            explicit_span=reference_pixel_span,
            point_a_x=reference_point_a_x,
            point_a_y=reference_point_a_y,
            point_b_x=reference_point_b_x,
            point_b_y=reference_point_b_y,
            image_width=image_width,
            image_height=image_height,
        )
        reference_height = self._positive_float(reference_height_m)

        if subject_span_px is None or reference_span_px is None or reference_height is None:
            if not self.is_available():
                raise RuntimeError(
                    "Metric measurement needs reference object calibration "
                    "because no MiDaS depth model is available."
                )

            raise RuntimeError(
                "MiDaS gives relative depth only. Send subject/reference pixel "
                "spans plus reference_height_m to convert the estimate to meters."
            )

        distance_ratio = self._distance_ratio(subject_distance_m, reference_distance_m)
        estimated_m = (subject_span_px / reference_span_px) * reference_height * distance_ratio
        if not math.isfinite(estimated_m) or estimated_m <= 0:
            raise ValueError("Unable to compute a valid metric measurement.")

        canonical_type = self._canonical_measurement_type(measurement_type)
        confidence = self._confidence(
            subject_span_px=subject_span_px,
            reference_span_px=reference_span_px,
            subject_distance_m=subject_distance_m,
            reference_distance_m=reference_distance_m,
        )
        midas_model_file_present = self.model_path is not None and self.model_path.exists()
        method = (
            "calibrated_reference_object_midas_ready"
            if midas_model_file_present
            else "calibrated_reference_object"
        )

        return {
            "mode": "measurement",
            "source": "python_ai_service",
            "height_m": round(estimated_m, 2) if canonical_type == "tree_height" else None,
            "canopy_width_m": round(estimated_m, 2) if canonical_type == "canopy_width" else None,
            "dbh_cm": None,
            "measurement_method": method,
            "confidence": confidence,
            "reference_object": {
                "height_m": reference_height,
                "distance_m": self._positive_float(reference_distance_m)
                or self._positive_float(subject_distance_m),
                "pixel_span": round(reference_span_px, 2),
            },
            "calibration": {
                "measurement_type": canonical_type,
                "subject_pixel_span": round(subject_span_px, 2),
                "reference_pixel_span": round(reference_span_px, 2),
                "subject_distance_m": self._positive_float(subject_distance_m),
                "reference_distance_m": self._positive_float(reference_distance_m),
                "distance_ratio": round(distance_ratio, 4),
                "image_width": image_width,
                "image_height": image_height,
            },
            "warning": self._warning(subject_distance_m, reference_distance_m),
            "message": "Calibrated metric measurement generated from reference object scale.",
        }

    def _load_model(self):
        if self._model is not None:
            return self._model

        if self.model_path is None:
            raise FileNotFoundError("MiDaS model file not found")

        try:
            import torch
        except Exception as exc:
            raise RuntimeError(f"PyTorch unavailable: {exc}") from exc

        try:
            self._model = torch.jit.load(str(self.model_path), map_location="cpu")
            self._model.eval()
            return self._model
        except Exception as exc:
            raise RuntimeError(f"MiDaS model could not be loaded: {exc}") from exc

    def _resolve_model_path(self) -> Path | None:
        configured_path = os.getenv("MIDAS_MODEL_PATH")
        if configured_path:
            path = Path(configured_path)
            if not path.is_absolute():
                path = self.service_root / path
            if path.exists():
                return path

        for folder in ("models/midas", "models/depth", "models/midas_depth"):
            directory = self.service_root / folder
            if not directory.exists():
                continue

            for pattern in ("*.pt", "*.pth", "*.onnx"):
                matches = sorted(directory.glob(pattern))
                if matches:
                    return matches[0]

        return None

    def expected_model_locations(self) -> list[Path]:
        return [
            self.service_root / "models" / "midas" / "midas_torchscript.pt",
            self.service_root / "models" / "depth" / "midas_torchscript.pt",
            self.service_root / "models" / "midas_depth" / "midas_torchscript.pt",
        ]

    def _image_dimensions(self, image_bytes: bytes) -> tuple[int, int]:
        try:
            with Image.open(io.BytesIO(image_bytes)) as image:
                return image.size
        except Exception as exc:
            raise ValueError(f"Invalid image bytes received: {exc}") from exc

    def _resolved_pixel_span(
        self,
        *,
        explicit_span: float | None,
        point_a_x: float | None,
        point_a_y: float | None,
        point_b_x: float | None,
        point_b_y: float | None,
        image_width: int,
        image_height: int,
    ) -> float | None:
        span = self._positive_float(explicit_span)
        if span is not None:
            return span

        points = (point_a_x, point_a_y, point_b_x, point_b_y)
        if any(value is None for value in points):
            return None

        ax = self._normalized_float(point_a_x)
        ay = self._normalized_float(point_a_y)
        bx = self._normalized_float(point_b_x)
        by = self._normalized_float(point_b_y)
        if None in (ax, ay, bx, by):
            return None

        return math.dist(
            (ax * image_width, ay * image_height),
            (bx * image_width, by * image_height),
        )

    def _positive_float(self, value: float | None) -> float | None:
        if value is None:
            return None

        try:
            numeric = float(value)
        except (TypeError, ValueError):
            return None

        if not math.isfinite(numeric) or numeric <= 0:
            return None

        return numeric

    def _normalized_float(self, value: float | None) -> float | None:
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            return None

        if not math.isfinite(numeric) or numeric < 0 or numeric > 1:
            return None

        return numeric

    def _distance_ratio(
        self,
        subject_distance_m: float | None,
        reference_distance_m: float | None,
    ) -> float:
        subject_distance = self._positive_float(subject_distance_m)
        reference_distance = self._positive_float(reference_distance_m)
        if subject_distance is None or reference_distance is None:
            return 1

        return subject_distance / reference_distance

    def _canonical_measurement_type(self, measurement_type: str | None) -> str:
        value = (measurement_type or "tree_height").strip().lower()
        if value in {"canopy", "canopy_width", "width"}:
            return "canopy_width"

        return "tree_height"

    def _confidence(
        self,
        *,
        subject_span_px: float,
        reference_span_px: float,
        subject_distance_m: float | None,
        reference_distance_m: float | None,
    ) -> float:
        confidence = 92.0
        if subject_span_px < 40:
            confidence -= 15
        if reference_span_px < 30:
            confidence -= 18
        if self._positive_float(subject_distance_m) is None:
            confidence -= 5
        if self._positive_float(reference_distance_m) is None:
            confidence -= 3

        return round(max(35.0, min(95.0, confidence)), 2)

    def _warning(
        self,
        subject_distance_m: float | None,
        reference_distance_m: float | None,
    ) -> str:
        if self._positive_float(subject_distance_m) and self._positive_float(reference_distance_m):
            return (
                "Perspective correction used. Accuracy still depends on placing "
                "measurement points exactly on the subject and reference object."
            )

        return (
            "Reference object is assumed to be beside the measured tree at the "
            "same distance from the camera."
        )
