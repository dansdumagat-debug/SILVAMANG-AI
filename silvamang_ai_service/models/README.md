# Uploaded Colab models

The service defaults use the uploaded EfficientNet-B0, YOLOv8-Detector,
YOLOv8-Seg, and MiDaS directories. Environment path overrides still apply.

Run `python scripts/prepare_uploaded_classifier.py` from the service directory
after replacing `EfficientNet-B0/efficientnet_b0_last.pth`. It validates the
recorded preprocessing, loads the 29-class network strictly, checks a forward
pass, and writes `efficientnet_b0_runtime.pth`, `class_order.json`, and
`runtime_provenance.json` alongside the original. This is the last-epoch model;
the previously reported test results for the best checkpoint do not apply to it.

Baseline-CNN is a comparison model and does not replace the main classifier.
YOLO class order is embedded in its checkpoints: leaf, bark, root, flower,
fruit_propagule. The YOLO training used automatic labels; their validation scores
are not independently reviewed field accuracy.

Install `requirements.txt`, `requirements-cnn.txt`, `requirements-yolo.txt`, and
`requirements-midas.txt` in the Python environment running the service. The
MiDaS loader supports the uploaded MiDaS_small state dictionary and older
TorchScript files. First load needs internet access to cache the official MiDaS
and gen-efficientnet architecture repositories. Local weights are loaded strictly.
MiDaS predicts relative depth. `/ai/measure` uses calibrated reference geometry;
it does not infer metric height from these weights.

Restart the Python service after replacing models and inspect `/ai/health`.
The Flutter offline assets now contain an ONNX export of the uploaded last-epoch
EfficientNet, its matching 29-class label list, and `model_metadata.json`.
`python scripts/export_uploaded_classifier_to_mobile.py` reproduces that export,
checks ONNX/PyTorch output parity, and backs up previous assets under
`artifacts/mobile_model_exports` before replacement. Rebuild the mobile app to
bundle these assets. The desktop ONNX check is not a physical-device test.
YOLO and calibrated measurements remain online service features; the baseline
is a comparison model. A hosted Python service must be deployed separately with
the new weights, dependencies, and configured model paths.
