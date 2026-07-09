def build_mock_measurement() -> dict:
    return {
        "mode": "mock",
        "height_m": 6.8,
        "canopy_width_m": 4.2,
        "dbh_cm": None,
        "measurement_method": "depth_estimation",
        "confidence": 88.0,
        "message": "Mock measurement result. Real depth estimation will be integrated later.",
    }

