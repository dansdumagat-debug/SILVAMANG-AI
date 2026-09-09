from __future__ import annotations

import importlib.util
from pathlib import Path


SERVICE_ROOT = Path(__file__).resolve().parents[1]


def has_module(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def first_existing(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.exists() and path.is_file():
            return path
    return None


def status_line(name: str, ready: bool, detail: str) -> str:
    status = "READY" if ready else "MISSING"
    return f"{name}: {status} - {detail}"


def main() -> None:
    cnn_model = SERVICE_ROOT / "models" / "cnn_classifier" / "efficientnet_b0_best.pth"
    cnn_classes = SERVICE_ROOT / "models" / "cnn_classifier" / "class_order.json"
    detector = first_existing(
        [
            SERVICE_ROOT / "models" / "yolo_detector" / "best.pt",
            SERVICE_ROOT / "models" / "yolo_detection" / "best.pt",
            SERVICE_ROOT / "models" / "yolo" / "best.pt",
        ]
    )
    segmenter = first_existing(
        [
            SERVICE_ROOT / "models" / "yolo_segmenter" / "best.pt",
            SERVICE_ROOT / "models" / "yolo_segmentation" / "best.pt",
            SERVICE_ROOT / "models" / "yolo_segment" / "best.pt",
            SERVICE_ROOT / "models" / "yolo" / "best.pt",
        ]
    )
    midas = first_existing(
        [
            SERVICE_ROOT / "models" / "midas" / "midas_torchscript.pt",
            SERVICE_ROOT / "models" / "depth" / "midas_torchscript.pt",
            SERVICE_ROOT / "models" / "midas_depth" / "midas_torchscript.pt",
        ]
    )

    print("SILVAMANG AI model readiness")
    print("=" * 34)
    print(status_line("torch", has_module("torch"), "required by CNN and MiDaS"))
    print(status_line("torchvision", has_module("torchvision"), "required by CNN"))
    print(status_line("ultralytics", has_module("ultralytics"), "required by YOLOv8"))
    print(status_line("CNN model", cnn_model.exists(), str(cnn_model)))
    print(status_line("CNN class order", cnn_classes.exists(), str(cnn_classes)))
    print(
        status_line(
            "YOLO detector",
            detector is not None,
            str(detector or SERVICE_ROOT / "models" / "yolo_detector" / "best.pt"),
        )
    )
    print(
        status_line(
            "YOLO segmenter",
            segmenter is not None,
            str(segmenter or SERVICE_ROOT / "models" / "yolo_segmenter" / "best.pt"),
        )
    )
    print(
        status_line(
            "MiDaS depth model",
            midas is not None,
            str(midas or SERVICE_ROOT / "models" / "midas" / "midas_torchscript.pt"),
        )
    )
    print()
    print("MiDaS metric measurements also need a scale source: ARCore/depth, known distance, or calibrated reference object.")


if __name__ == "__main__":
    main()
