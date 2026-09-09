from app.core.config import settings


def build_mock_prediction(
    plant_parts: list[str] | None = None,
    image_count: int = 0,
    latitude: float | None = None,
    longitude: float | None = None,
) -> dict:
    received_plant_parts = plant_parts or []

    return {
        "mode": "mock",
        "source": "mock_fallback",
        "warning": "No valid CNN prediction was produced.",
        "model": {
            "name": "SILVAMANG Mock Classifier",
            "version": settings.mock_model_version,
            "type": "classification",
        },
        "top_prediction": {
            "species_id": None,
            "scientific_name": "",
            "common_name": None,
            "confidence": None,
        },
        "predictions": [],
        "explanation": (
            "No valid species prediction is available from the fallback path. "
            "Capture or select an image and use the CNN service for real identification."
        ),
        "measurement": {
            "height_m": None,
            "canopy_width_m": None,
            "dbh_cm": None,
            "measurement_method": "not_estimated",
            "confidence": None,
        },
        "location_hint": {
            "latitude": latitude,
            "longitude": longitude,
            "message": "Location validation should be completed by the Laravel backend.",
        },
        "received": {
            "plant_parts": received_plant_parts,
            "image_count": image_count,
        },
    }
