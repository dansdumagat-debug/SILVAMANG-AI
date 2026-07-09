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
        "model": {
            "name": "SILVAMANG Mock Classifier",
            "version": settings.mock_model_version,
            "type": "classification",
        },
        "top_prediction": {
            "species_id": 1,
            "scientific_name": "Rhizophora apiculata",
            "common_name": "Red Mangrove",
            "confidence": 92.4,
        },
        "predictions": [
            {
                "rank": 1,
                "species_id": 1,
                "scientific_name": "Rhizophora apiculata",
                "common_name": "Red Mangrove",
                "confidence": 92.4,
            },
            {
                "rank": 2,
                "species_id": 2,
                "scientific_name": "Rhizophora mucronata",
                "common_name": "Red Mangrove",
                "confidence": 5.1,
            },
            {
                "rank": 3,
                "species_id": 5,
                "scientific_name": "Bruguiera gymnorrhiza",
                "common_name": "Large-leaved Orange Mangrove",
                "confidence": 2.5,
            },
        ],
        "explanation": (
            "This mock result suggests Rhizophora apiculata based on the "
            "prototype classification workflow. Real CNN and YOLOv8 inference "
            "will be integrated in a later phase."
        ),
        "measurement": {
            "height_m": 6.8,
            "canopy_width_m": 4.2,
            "dbh_cm": None,
            "measurement_method": "depth_estimation",
            "confidence": 88.0,
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

