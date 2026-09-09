import io

from fastapi.testclient import TestClient
from PIL import Image

from app.main import app


client = TestClient(app)


def _image_bytes() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (100, 100), "white").save(buffer, format="JPEG")
    return buffer.getvalue()


def test_ai_measure_uses_reference_object_calibration_without_midas_model() -> None:
    response = client.post(
        "/ai/measure",
        data={
            "measurement_type": "tree_height",
            "reference_height_m": "1",
            "subject_pixel_span": "80",
            "reference_pixel_span": "20",
        },
        files={"image": ("tree.jpg", _image_bytes(), "image/jpeg")},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "success"
    assert payload["height_m"] == 4
    assert payload["canopy_width_m"] is None
    assert payload["measurement_method"] == "calibrated_reference_object"

