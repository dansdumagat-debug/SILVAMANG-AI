import io

from fastapi.testclient import TestClient
from PIL import Image

from app.main import app


client = TestClient(app)


def test_retired_mock_measurement_does_not_return_fabricated_values():
    response = client.post('/measure')
    assert response.status_code == 410
    assert 'height_m' not in response.json()


def test_reference_measurement_requires_calibration():
    response = client.post('/ai/measure', files={'image': ('tree.jpg', _image_bytes(), 'image/jpeg')})
    assert response.json()['status'] == 'error'
    assert 'reference' in response.json()['message'].lower()
    assert 'height_m' not in response.json()


def test_readiness_requires_only_classifier_and_yolo(monkeypatch):
    import app.main as main
    ready = {'available': True, 'model_file': 'test-model', 'load_error': None}
    for service in [main.cnn_prediction_service, main.yolo_detection_service, main.yolo_segmentation_service]:
        monkeypatch.setattr(service, 'readiness', lambda: ready)
    monkeypatch.setattr(main.cnn_prediction_service, 'class_order', lambda: ['unknown'])
    payload = client.get('/ai/health').json()
    assert payload['ready'] is True
    assert set(payload['models']) == {'cnn', 'yolov8', 'segmentation'}


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

