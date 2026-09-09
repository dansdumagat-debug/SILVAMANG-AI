from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]

REQUIRED_FILES = [
    ROOT / "silvamang_ai_service" / "reports" / "cnn_baseline" / "metrics.json",
    ROOT / "silvamang_ai_service" / "reports" / "cnn_baseline" / "confusion_matrix.png",
    ROOT / "docs" / "testing" / "functional_test_cases.csv",
    ROOT / "docs" / "testing" / "api_test_cases.csv",
    ROOT / "docs" / "testing" / "usability_evaluation_form.md",
    ROOT / "docs" / "testing" / "requirements_traceability_matrix.csv",
]


def main() -> None:
    print("SILVAMANG AI testing evidence summary")
    for path in REQUIRED_FILES:
        status = "present" if path.exists() else "missing"
        print(f"{status}: {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
