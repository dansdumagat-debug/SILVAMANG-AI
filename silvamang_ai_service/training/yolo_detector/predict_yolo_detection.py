import argparse
from pathlib import Path

try:
    from .config import MODEL_OUTPUT_PATH, REPORT_OUTPUT_PATH
    from .utils import ensure_dir
except ImportError:
    from config import MODEL_OUTPUT_PATH, REPORT_OUTPUT_PATH
    from utils import ensure_dir


def main():
    parser = argparse.ArgumentParser(description="Run future YOLOv8 plant-part detection on one image.")
    parser.add_argument("--image", required=True, help="Path to image.")
    parser.add_argument("--model", default=str(MODEL_OUTPUT_PATH / "best.pt"), help="Path to trained YOLO model.")
    args = parser.parse_args()

    try:
        from ultralytics import YOLO
    except ImportError:
        print("Ultralytics is not installed. Run: pip install -r silvamang_ai_service/requirements-yolo.txt")
        return

    image_path = Path(args.image)
    model_path = Path(args.model)

    if not model_path.exists():
        print(f"YOLO model not found: {model_path}")
        return

    if not image_path.exists():
        print(f"Image file not found: {image_path}")
        return

    output_dir = REPORT_OUTPUT_PATH / "predictions"
    ensure_dir(output_dir)
    YOLO(str(model_path)).predict(source=str(image_path), save=True, project=str(output_dir), name="detection")
    print(f"Annotated prediction output saved under: {output_dir}")


if __name__ == "__main__":
    main()
