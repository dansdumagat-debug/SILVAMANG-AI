try:
    from .config import MODEL_OUTPUT_PATH, REPORT_OUTPUT_PATH, YOLO_DETECTION_DATASET_PATH
except ImportError:
    from config import MODEL_OUTPUT_PATH, REPORT_OUTPUT_PATH, YOLO_DETECTION_DATASET_PATH


def main():
    try:
        from ultralytics import YOLO
    except ImportError:
        print("Ultralytics is not installed. Run: pip install -r silvamang_ai_service/requirements-yolo.txt")
        return

    model_path = MODEL_OUTPUT_PATH / "best.pt"
    if not model_path.exists():
        print("YOLO model not found. Train YOLO detection first.")
        return

    data_yaml = YOLO_DETECTION_DATASET_PATH / "data.yaml"
    if not data_yaml.exists():
        print(f"YOLO detection data.yaml not found: {data_yaml}")
        return

    print("Running YOLO detection validation. Metrics include precision, recall, mAP50, mAP50-95, and IoU.")
    print(f"Ultralytics validation outputs will be generated under: {REPORT_OUTPUT_PATH}")
    YOLO(str(model_path)).val(data=str(data_yaml), project=str(REPORT_OUTPUT_PATH), name="detection_eval")


if __name__ == "__main__":
    main()
