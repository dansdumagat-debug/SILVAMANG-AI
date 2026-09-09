# AI Evaluation Summary

## 1. CNN Baseline Evaluation
CNN baseline evaluation evidence should be taken only from generated evaluation files.

Available expected paths:
- `silvamang_ai_service/reports/cnn_baseline/metrics.json`
- `silvamang_ai_service/reports/cnn_baseline/classification_report.csv`
- `silvamang_ai_service/reports/cnn_baseline/confusion_matrix.png`

## 2. Dataset Summary
Use actual dataset summaries from dataset scripts or verified exported files. Do not fabricate dataset counts.

## 3. Metrics Used
Accuracy, precision, recall, F1-score, top-3 accuracy, classification report, and confusion matrix.

## 4. Accuracy
Record from `metrics.json` when available.

## 5. Precision
Record from `metrics.json` and `classification_report.csv` when available.

## 6. Recall
Record from `metrics.json` and `classification_report.csv` when available.

## 7. F1-score
Record from `metrics.json` and `classification_report.csv` when available.

## 8. Top-3 Accuracy
Record from `metrics.json` when available.

## 9. Confusion Matrix
Use `silvamang_ai_service/reports/cnn_baseline/confusion_matrix.png` when available.

## 10. Limitations
CNN baseline results depend on available dataset quality and class balance.

## 11. YOLO Status
YOLO training is pending because bounding-box annotations are not yet available.

## 12. Depth Estimation Status
Measurement currently uses prototype/mock depth-estimation response until real MiDaS integration is implemented.
