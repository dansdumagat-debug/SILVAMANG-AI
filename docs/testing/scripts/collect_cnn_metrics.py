import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
METRICS_PATH = ROOT / "silvamang_ai_service" / "reports" / "cnn_baseline" / "metrics.json"


def main() -> None:
    if not METRICS_PATH.exists():
        print("CNN metrics file not found. Run evaluate_cnn_baseline.py first.")
        return

    metrics = json.loads(METRICS_PATH.read_text(encoding="utf-8"))
    print(f"CNN metrics: {METRICS_PATH}")
    for key, value in metrics.items():
        print(f"{key}: {value}")


if __name__ == "__main__":
    main()
