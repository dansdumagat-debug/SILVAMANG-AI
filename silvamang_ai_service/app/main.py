from typing import Annotated

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.schemas.measurement_schema import MeasurementResponse
from app.schemas.prediction_schema import MockPredictionResponse
from app.services.mock_measurement_service import build_mock_measurement
from app.services.mock_prediction_service import build_mock_prediction
from app.utils.image_utils import count_uploaded_images

app = FastAPI(title=settings.app_name, version=settings.mock_model_version)

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
    return {
        "status": "ok",
        "service": settings.app_name,
        "mode": settings.model_mode,
        "version": settings.mock_model_version,
    }


@app.post("/predict", response_model=MockPredictionResponse)
async def predict(
    images: Annotated[list[UploadFile] | None, File()] = None,
    plant_parts: Annotated[list[str] | None, Form()] = None,
    latitude: Annotated[float | None, Form()] = None,
    longitude: Annotated[float | None, Form()] = None,
) -> dict:
    image_count = await count_uploaded_images(images)

    return {
        "message": "Mock AI prediction completed successfully.",
        "data": build_mock_prediction(
            plant_parts=plant_parts,
            image_count=image_count,
            latitude=latitude,
            longitude=longitude,
        ),
    }


@app.post("/measure", response_model=MeasurementResponse)
async def measure(
    image: Annotated[UploadFile | None, File()] = None,
) -> dict:
    _ = image

    return {
        "message": "Mock measurement completed successfully.",
        "data": build_mock_measurement(),
    }

