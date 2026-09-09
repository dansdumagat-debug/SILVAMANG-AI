import argparse

try:
    from .config import (
        DEFAULT_BATCH_SIZE,
        DEFAULT_EPOCHS,
        DEFAULT_IMAGE_SIZE,
        DEFAULT_SEGMENTATION_MODEL,
        REPORT_OUTPUT_PATH,
        YOLO_SEGMENTATION_DATASET_PATH,
    )
    from .utils import count_images, count_label_files, ensure_dir
except ImportError:
    from config import (
        DEFAULT_BATCH_SIZE,
        DEFAULT_EPOCHS,
        DEFAULT_IMAGE_SIZE,
        DEFAULT_SEGMENTATION_MODEL,
        REPORT_OUTPUT_PATH,
        YOLO_SEGMENTATION_DATASET_PATH,
    )
    from utils import count_images, count_label_files, ensure_dir


def main():
    parser = argparse.ArgumentParser(description="Train future YOLOv8-Seg plant-part segmenter.")
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS)
    parser.add_argument("--imgsz", type=int, default=DEFAULT_IMAGE_SIZE)
    parser.add_argument("--batch", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--model", default=DEFAULT_SEGMENTATION_MODEL)
    parser.add_argument("--run", action="store_true", help="Run training when segmentation data exists.")
    args = parser.parse_args()

    try:
        from ultralytics import YOLO
    except ImportError:
        print("Ultralytics is not installed. Run: pip install -r silvamang_ai_service/requirements-yolo.txt")
        return

    data_yaml = YOLO_SEGMENTATION_DATASET_PATH / "data.yaml"
    if not data_yaml.exists():
        print(f"YOLO segmentation data.yaml not found: {data_yaml}")
        return

    if count_images(YOLO_SEGMENTATION_DATASET_PATH / "images" / "train") == 0 or count_label_files(YOLO_SEGMENTATION_DATASET_PATH / "labels" / "train") == 0:
        print("No YOLO segmentation annotations found. Create segmentation masks/polygon labels first.")
        return

    if not args.run:
        print("YOLO segmentation data is ready. Re-run with --run to start training manually.")
        return

    ensure_dir(REPORT_OUTPUT_PATH)
    YOLO(args.model).train(
        data=str(data_yaml),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        project=str(REPORT_OUTPUT_PATH),
        name="segmentation",
    )


if __name__ == "__main__":
    main()
