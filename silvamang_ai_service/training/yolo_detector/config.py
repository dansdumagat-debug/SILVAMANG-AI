from pathlib import Path


AI_SERVICE_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = AI_SERVICE_ROOT.parent

YOLO_DETECTION_DATASET_PATH = PROJECT_ROOT / "dataset" / "processed" / "yolo_detection"
YOLO_SEGMENTATION_DATASET_PATH = PROJECT_ROOT / "dataset" / "processed" / "yolo_segmentation"
YOLO_CLASS_LABELS_PATH = PROJECT_ROOT / "dataset" / "labels" / "yolo_classes.txt"

MODEL_OUTPUT_PATH = AI_SERVICE_ROOT / "models" / "yolo_detector"
REPORT_OUTPUT_PATH = AI_SERVICE_ROOT / "reports" / "yolo_detector"

DEFAULT_MODEL = "yolov8n.pt"
DEFAULT_SEGMENTATION_MODEL = "yolov8n-seg.pt"
DEFAULT_EPOCHS = 50
DEFAULT_IMAGE_SIZE = 640
DEFAULT_BATCH_SIZE = 8
RANDOM_SEED = 42
