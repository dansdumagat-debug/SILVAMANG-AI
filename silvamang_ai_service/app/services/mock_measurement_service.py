def build_mock_measurement(
    image_count: int = 0,
    reference_height_m: float | None = None,
    reference_distance_m: float | None = None,
) -> dict:
    return {
        "mode": "mock",
        "source": "python_ai_service",
        "height_m": 6.8,
        "canopy_width_m": 4.2,
        "dbh_cm": None,
        "measurement_method": "depth_estimation_mock",
        "confidence": 88.0,
        "reference_object": {
            "height_m": reference_height_m,
            "distance_m": reference_distance_m,
        },
        "image_count": image_count,
        "warning": "This is a prototype measurement estimate. Real MiDaS depth estimation will be integrated later.",
        "message": "Mock measurement result generated successfully.",
    }
