import base64
import binascii
from typing import Annotated

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.schemas.measurement_schema import MeasurementResponse
from app.schemas.prediction_schema import MockPredictionResponse
from app.services.cnn_prediction_service import CNNPredictionService
from app.services.midas_measurement_service import MidasMeasurementService
from app.services.mock_measurement_service import build_mock_measurement
from app.services.mock_prediction_service import build_mock_prediction
from app.services.yolo_vision_service import YOLOVisionService
from app.utils.image_utils import count_uploaded_images

app = FastAPI(title=settings.app_name, version=settings.mock_model_version)
cnn_prediction_service = CNNPredictionService()
yolo_detection_service = YOLOVisionService("detection")
yolo_segmentation_service = YOLOVisionService("segmentation")
midas_measurement_service = MidasMeasurementService()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:8000",
        "http://localhost:8000",
        "http://10.0.2.2:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root() -> dict:
    return {
        "message": "SILVAMANG AI Service is running.",
        "mode": settings.model_mode,
    }


@app.get("/health")
async def health() -> dict:
    cnn_available = cnn_prediction_service.is_available()
    class_order = cnn_prediction_service.class_order() if cnn_available else []

    return {
        "status": "ok",
        "service": settings.app_name,
        "mode": "cnn_efficientnet_b0_available" if cnn_available else "mock",
        "version": settings.mock_model_version,
        "cnn": {
            "model_path": str(cnn_prediction_service.model_path),
            "model_file": cnn_prediction_service.model_path.name,
            "available": cnn_available,
            "efficientnet_available": cnn_available,
            "classes": len(class_order),
            "class_count": len(class_order),
            "class_order": class_order,
            "load_error": cnn_prediction_service.load_error(),
        },
        "measurement": {
            "mode": "mock",
            "available": True,
            "method": "depth_estimation_mock",
        },
    }


@app.get("/ai/health")
async def ai_health() -> dict:
    cnn_ready = cnn_prediction_service.readiness()
    yolo_ready = yolo_detection_service.readiness()
    segmentation_ready = yolo_segmentation_service.readiness()
    midas_ready = midas_measurement_service.readiness()
    cnn_available = bool(cnn_ready["available"])
    yolo_available = bool(yolo_ready["available"])
    segmentation_available = bool(segmentation_ready["available"])
    midas_available = bool(midas_ready["available"])
    class_order = cnn_prediction_service.class_order() if cnn_available else []
    all_ready = all(
        [
            cnn_available,
            yolo_available,
            segmentation_available,
            midas_available,
        ]
    )

    return {
        "service": "online",
        "status": "ready" if all_ready else "partial",
        "models": {
            "cnn": cnn_available,
            "yolov8": yolo_available,
            "segmentation": segmentation_available,
            "midas": midas_available,
        },
        "ready": all_ready,
        "endpoints": {
            "cnn": "/ai/classify",
            "yolov8": "/ai/detect",
            "segmentation": "/ai/segment",
            "midas": "/ai/measure",
        },
        "model_versions": {
            "cnn": cnn_ready["model_file"] if cnn_available else None,
            "yolov8": yolo_ready["model_file"] if yolo_available else None,
            "segmentation": segmentation_ready["model_file"]
            if segmentation_available
            else None,
            "midas": midas_ready["model_file"] if midas_available else None,
        },
        "class_count": len(class_order),
        "class_order": class_order,
        "readiness": {
            "cnn": cnn_ready,
            "yolov8": yolo_ready,
            "segmentation": segmentation_ready,
            "midas": midas_ready,
        },
        "errors": {
            "cnn": cnn_ready["load_error"],
            "yolov8": yolo_ready["load_error"],
            "segmentation": segmentation_ready["load_error"],
            "midas": midas_ready["load_error"],
        },
    }


@app.post("/ai/classify")
async def ai_classify(
    image: Annotated[
        UploadFile | None,
        File(description="Mangrove image file"),
    ] = None,
    image_base64: Annotated[
        str | None,
        Form(description="Base64 encoded mangrove image"),
    ] = None,
) -> dict:
    if not cnn_prediction_service.is_available():
        return {
            "status": "error",
            "message": "CNN model unavailable",
        }

    try:
        image_bytes = await _read_image_bytes(
            image=image,
            image_base64=image_base64,
        )
        prediction = cnn_prediction_service.predict_image(
            image_bytes=image_bytes,
            top_k=3,
        )
    except ValueError as exc:
        return {
            "status": "error",
            "message": str(exc),
        }
    except Exception as exc:
        return {
            "status": "error",
            "message": f"CNN classification failed: {exc}",
        }

    top_prediction = prediction["top_prediction"]

    return {
        "status": "success",
        "species_name": top_prediction["scientific_name"],
        "confidence": top_prediction["confidence"],
        "model_name": "SILVAMANG CNN Classifier",
        "version": prediction["model"]["version"],
        "predictions": prediction["predictions"],
    }


@app.post("/ai/detect")
async def ai_detect(
    image: Annotated[
        UploadFile | None,
        File(description="Mangrove image file"),
    ] = None,
    image_base64: Annotated[
        str | None,
        Form(description="Base64 encoded mangrove image"),
    ] = None,
) -> dict:
    if not yolo_detection_service.is_available():
        return {
            "status": "error",
            "message": "YOLOv8 detection model unavailable",
        }

    try:
        image_bytes = await _read_image_bytes(
            image=image,
            image_base64=image_base64,
        )
        return {
            "status": "success",
            "detections": yolo_detection_service.detect(image_bytes),
        }
    except ValueError as exc:
        return {
            "status": "error",
            "message": str(exc),
        }
    except Exception as exc:
        return {
            "status": "error",
            "message": f"YOLOv8 detection failed: {exc}",
        }


@app.post("/ai/segment")
async def ai_segment(
    image: Annotated[
        UploadFile | None,
        File(description="Mangrove image file"),
    ] = None,
    image_base64: Annotated[
        str | None,
        Form(description="Base64 encoded mangrove image"),
    ] = None,
) -> dict:
    if not yolo_segmentation_service.is_available():
        return {
            "status": "error",
            "message": "YOLOv8 segmentation model unavailable",
        }

    try:
        image_bytes = await _read_image_bytes(
            image=image,
            image_base64=image_base64,
        )
        segmentation = yolo_segmentation_service.segment(image_bytes)
        return {
            "status": "success",
            **segmentation,
        }
    except ValueError as exc:
        return {
            "status": "error",
            "message": str(exc),
        }
    except Exception as exc:
        return {
            "status": "error",
            "message": f"YOLOv8 segmentation failed: {exc}",
        }


@app.post("/ai/measure")
async def ai_measure(
    image: Annotated[
        UploadFile | None,
        File(description="Mangrove image file"),
    ] = None,
    image_base64: Annotated[
        str | None,
        Form(description="Base64 encoded mangrove image"),
    ] = None,
    measurement_type: Annotated[
        str | None,
        Form(description="tree_height or canopy_width"),
    ] = None,
    reference_height_m: Annotated[
        float | None,
        Form(description="Known reference object height in meters"),
    ] = None,
    subject_distance_m: Annotated[
        float | None,
        Form(description="Camera-to-tree distance in meters"),
    ] = None,
    reference_distance_m: Annotated[
        float | None,
        Form(description="Camera-to-reference-object distance in meters"),
    ] = None,
    subject_pixel_span: Annotated[
        float | None,
        Form(description="Marked subject span in rendered image pixels"),
    ] = None,
    reference_pixel_span: Annotated[
        float | None,
        Form(description="Marked reference object span in rendered image pixels"),
    ] = None,
    subject_point_a_x: Annotated[float | None, Form()] = None,
    subject_point_a_y: Annotated[float | None, Form()] = None,
    subject_point_b_x: Annotated[float | None, Form()] = None,
    subject_point_b_y: Annotated[float | None, Form()] = None,
    reference_point_a_x: Annotated[float | None, Form()] = None,
    reference_point_a_y: Annotated[float | None, Form()] = None,
    reference_point_b_x: Annotated[float | None, Form()] = None,
    reference_point_b_y: Annotated[float | None, Form()] = None,
) -> dict:
    try:
        image_bytes = await _read_image_bytes(
            image=image,
            image_base64=image_base64,
        )
        measurement = midas_measurement_service.measure(
            image_bytes,
            measurement_type=measurement_type,
            reference_height_m=reference_height_m,
            subject_distance_m=subject_distance_m,
            reference_distance_m=reference_distance_m,
            subject_pixel_span=subject_pixel_span,
            reference_pixel_span=reference_pixel_span,
            subject_point_a_x=subject_point_a_x,
            subject_point_a_y=subject_point_a_y,
            subject_point_b_x=subject_point_b_x,
            subject_point_b_y=subject_point_b_y,
            reference_point_a_x=reference_point_a_x,
            reference_point_a_y=reference_point_a_y,
            reference_point_b_x=reference_point_b_x,
            reference_point_b_y=reference_point_b_y,
        )
        return {
            "status": "success",
            **measurement,
            "model_name": "SILVAMANG Calibrated Measurement",
        }
    except ValueError as exc:
        return {
            "status": "error",
            "message": str(exc),
        }
    except Exception as exc:
        return {
            "status": "error",
            "message": f"MiDaS measurement failed: {exc}",
        }


@app.post("/predict", response_model=MockPredictionResponse)
async def predict(
    images: Annotated[
        list[UploadFile],
        File(description="Mangrove image files"),
    ] = [],
    image: Annotated[
        UploadFile | None,
        File(description="Single mangrove image for Swagger testing"),
    ] = None,
    plant_parts: Annotated[
        list[str],
        Form(description="Plant part labels"),
    ] = [],
    latitude: Annotated[float | None, Form()] = None,
    longitude: Annotated[float | None, Form()] = None,
) -> dict:
    uploaded_images = list(images or [])
    if image is not None:
        uploaded_images.append(image)

    image_count = len(uploaded_images)

    if uploaded_images and cnn_prediction_service.is_available():
        try:
            image_bytes = await uploaded_images[0].read()
            prediction = cnn_prediction_service.predict_image(image_bytes=image_bytes, top_k=3)
            prediction["received"] = {
                "plant_parts": plant_parts,
                "image_count": image_count,
            }
            prediction["location_hint"]["latitude"] = latitude
            prediction["location_hint"]["longitude"] = longitude

            return {
                "message": "AI prediction completed using EfficientNet-B0 CNN.",
                "data": prediction,
            }
        except Exception:
            fallback = build_mock_prediction(
                plant_parts=plant_parts,
                image_count=image_count,
                latitude=latitude,
                longitude=longitude,
            )
            fallback["source"] = "mock_fallback"
            fallback["warning"] = "EfficientNet-B0 CNN unavailable. Mock fallback prediction was used."

            return {
                "message": "AI prediction completed using mock fallback.",
                "data": fallback,
            }

    fallback = build_mock_prediction(
        plant_parts=plant_parts,
        image_count=image_count,
        latitude=latitude,
        longitude=longitude,
    )
    if uploaded_images:
        fallback["source"] = "mock_fallback"
        fallback["warning"] = "EfficientNet-B0 CNN unavailable. Mock fallback prediction was used."
    else:
        fallback["source"] = "mock_fallback"
        fallback["warning"] = "No image was received. Mock fallback prediction was used."

    return {
        "message": "AI prediction completed using mock fallback.",
        "data": fallback,
    }


@app.post("/predict-test", response_model=MockPredictionResponse)
async def predict_test(
    image: UploadFile = File(..., description="Upload one mangrove image"),
    plant_part: str = Form(default="leaves"),
    latitude: float | None = Form(default=None),
    longitude: float | None = Form(default=None),
) -> dict:
    image_bytes = await image.read()
    plant_parts = [plant_part]

    if cnn_prediction_service.is_available():
        try:
            prediction = cnn_prediction_service.predict_image(
                image_bytes=image_bytes,
                top_k=3,
            )
            prediction["received"] = {
                "plant_parts": plant_parts,
                "image_count": 1,
            }
            prediction["location_hint"]["latitude"] = latitude
            prediction["location_hint"]["longitude"] = longitude

            return {
                "message": "AI prediction completed using EfficientNet-B0 CNN.",
                "data": prediction,
            }
        except Exception:
            pass

    fallback = build_mock_prediction(
        plant_parts=plant_parts,
        image_count=1,
        latitude=latitude,
        longitude=longitude,
    )
    fallback["source"] = "mock_fallback"
    fallback["warning"] = "EfficientNet-B0 CNN unavailable. Mock fallback prediction was used."

    return {
        "message": "AI prediction completed using mock fallback.",
        "data": fallback,
    }


async def _read_image_bytes(
    image: UploadFile | None,
    image_base64: str | None,
) -> bytes:
    if image is not None:
        image_bytes = await image.read()
        if image_bytes:
            return image_bytes

    if image_base64:
        payload = image_base64.strip()
        if "," in payload and payload.lower().startswith("data:"):
            payload = payload.split(",", 1)[1]

        try:
            decoded = base64.b64decode(payload, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise ValueError("Invalid base64 image input") from exc

        if decoded:
            return decoded

    raise ValueError("No image file or base64 image was received")


@app.post("/measure", response_model=MeasurementResponse)
async def measure(
    image: Annotated[UploadFile | None, File()] = None,
    images: Annotated[list[UploadFile] | None, File()] = None,
    reference_height_m: Annotated[float | None, Form()] = None,
    reference_distance_m: Annotated[float | None, Form()] = None,
) -> dict:
    image_count = await count_uploaded_images(images)
    if image is not None:
        image_count += 1

    return {
        "message": "Mock AI measurement completed successfully.",
        "data": build_mock_measurement(
            image_count=image_count,
            reference_height_m=reference_height_m,
            reference_distance_m=reference_distance_m,
        ),
    }
