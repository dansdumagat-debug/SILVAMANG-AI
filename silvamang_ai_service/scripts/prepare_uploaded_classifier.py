"""Build an inference bundle from the uploaded Colab last-epoch checkpoint.

Run from the service directory: python scripts/prepare_uploaded_classifier.py
Original weights are preserved; this does not claim best-checkpoint test scores.
"""
import hashlib
import json
from pathlib import Path

import torch
from torchvision import models


def main():
    folder = Path(__file__).resolve().parents[1] / "models" / "EfficientNet-B0"
    source = folder / "efficientnet_b0_last.pth"
    checkpoint = torch.load(source, map_location="cpu", weights_only=True)
    config = checkpoint["training_config"]
    classes = config["classes"]
    if not classes or len(set(classes)) != len(classes):
        raise ValueError("Invalid class order in checkpoint")
    transform = config.get("eval_transform", "")
    for expected in ("Resize(size=256", "CenterCrop(size=(224, 224))",
                     "mean=[0.485, 0.456, 0.406]", "std=[0.229, 0.224, 0.225]"):
        if expected not in transform:
            raise ValueError(f"Unrecognized preprocessing: missing {expected}")
    model = models.efficientnet_b0(weights=None)
    model.classifier[1] = torch.nn.Linear(model.classifier[1].in_features, len(classes))
    model.load_state_dict(checkpoint["model_state_dict"], strict=True)
    model.eval()
    with torch.inference_mode():
        output = model(torch.zeros(1, 3, 224, 224))
    if output.shape != (1, len(classes)) or not torch.isfinite(output).all():
        raise ValueError("Classifier forward pass failed")
    provenance = {
        "source_file": source.name,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "checkpoint_selection": "last",
        "completed_epoch": checkpoint["completed_epoch"],
        "test_metrics": None,
    }
    bundle = {
        "model_name": "efficientnet_b0", "image_size": 224,
        "classes": classes, "model_state_dict": model.state_dict(),
        "provenance": provenance,
    }
    destination = folder / "efficientnet_b0_runtime.pth"
    torch.save(bundle, destination)
    (folder / "class_order.json").write_text(json.dumps(classes, indent=2) + "\n", encoding="utf-8")
    (folder / "runtime_provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {destination}: {len(classes)} classes, last epoch {checkpoint['completed_epoch']}")


if __name__ == "__main__":
    main()
