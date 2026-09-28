"""Export the prepared uploaded classifier and verify before replacing app assets."""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
from torchvision import models


def main():
    root = Path(__file__).resolve().parents[2]
    source = root / "silvamang_ai_service/models/EfficientNet-B0/efficientnet_b0_runtime.pth"
    checkpoint = torch.load(source, map_location="cpu", weights_only=True)
    classes = checkpoint["classes"]
    if checkpoint["image_size"] != 224 or checkpoint["model_name"] != "efficientnet_b0":
        raise ValueError("Unsupported runtime checkpoint")
    torch.set_num_threads(2)
    torch.manual_seed(42)
    model = models.efficientnet_b0(weights=None)
    model.classifier[1] = torch.nn.Linear(1280, len(classes))
    model.load_state_dict(checkpoint["model_state_dict"], strict=True)
    model.eval()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    staging = root / "artifacts/mobile_model_exports" / stamp
    staging.mkdir(parents=True)
    filename = "efficientnet_b0_silvamang_single.onnx"
    exported = staging / filename
    torch.onnx.export(
        model, torch.zeros(1, 3, 224, 224), str(exported),
        input_names=["input"], output_names=["logits"],
        opset_version=14, dynamo=False, external_data=False,
    )
    graph = onnx.load(str(exported), load_external_data=False)
    onnx.checker.check_model(graph)
    if any(t.data_location == onnx.TensorProto.EXTERNAL for t in graph.graph.initializer):
        raise ValueError("Mobile model must be a single file")
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    session = ort.InferenceSession(str(exported), sess_options=options, providers=["CPUExecutionProvider"])
    errors = []
    probability_errors = []
    for tensor in (torch.zeros(1, 3, 224, 224), torch.ones(1, 3, 224, 224), torch.randn(1, 3, 224, 224)):
        with torch.inference_mode():
            expected = model(tensor).numpy()
        actual = session.run(None, {"input": tensor.numpy()})[0]
        assert actual.shape == (1, len(classes))
        # Optimized CPU kernels can approximate fused activations. Check both
        # logits and the probabilities consumed by the app, with explicit bounds.
        np.testing.assert_allclose(actual, expected, rtol=1e-3, atol=5e-3)
        expected_prob = torch.softmax(torch.from_numpy(expected), dim=1).numpy()
        actual_prob = torch.softmax(torch.from_numpy(actual), dim=1).numpy()
        np.testing.assert_allclose(actual_prob, expected_prob, rtol=0, atol=1e-3)
        probability_errors.append(float(np.max(np.abs(actual_prob - expected_prob))))
        assert actual.argmax() == expected.argmax()
        errors.append(float(np.max(np.abs(actual - expected))))
    (staging / "class_order.json").write_text(json.dumps(classes, indent=2) + "\n", encoding="utf-8")
    metadata = {
        "version": "colab-20260926-last-epoch23", "class_count": len(classes),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "onnx_sha256": hashlib.sha256(exported.read_bytes()).hexdigest(),
        "source_provenance": checkpoint["provenance"],
        "input_shape": [1, 3, 224, 224], "output": "logits",
        "mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225],
        "resize_short_side": 256, "center_crop": 224,
        "parity_max_absolute_errors": errors,
        "parity_max_probability_errors": probability_errors,
        "validation_note": "Synthetic tensor export parity, not an accuracy evaluation or device test",
    }
    (staging / "model_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    target = root / "silvamang_mobile/assets/models"
    backup = staging / "previous_mobile_bundle"
    backup.mkdir()
    for name in (filename, "class_order.json", "model_metadata.json"):
        if (target / name).exists():
            shutil.copy2(target / name, backup / name)
        shutil.copy2(staging / name, target / name)
    print(f"Updated mobile bundle: {len(classes)} classes; max logit error {max(errors):.8f}")
    print(f"Export evidence and previous asset backup: {staging}")


if __name__ == "__main__":
    main()
