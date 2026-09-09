from pathlib import Path


AI_SERVICE_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = AI_SERVICE_ROOT.parent

RAW_DATASET_PATH = PROJECT_ROOT / "dataset" / "raw"
PROCESSED_DATASET_PATH = PROJECT_ROOT / "dataset" / "processed" / "cnn_classification"
LABELS_PATH = PROJECT_ROOT / "dataset" / "labels" / "species_labels.txt"

MODEL_OUTPUT_PATH = AI_SERVICE_ROOT / "models" / "cnn_classifier" / "baseline_cnn.pth"
REPORTS_OUTPUT_PATH = AI_SERVICE_ROOT / "reports" / "cnn_baseline"

DEFAULT_IMAGE_SIZE = 224
DEFAULT_BATCH_SIZE = 16
DEFAULT_EPOCHS = 10
DEFAULT_LEARNING_RATE = 0.001

TRAIN_SPLIT = 0.70
VAL_SPLIT = 0.20
TEST_SPLIT = 0.10

RANDOM_SEED = 42
