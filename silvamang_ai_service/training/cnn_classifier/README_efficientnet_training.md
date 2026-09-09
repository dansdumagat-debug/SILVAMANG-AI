# EfficientNet Transfer-Learning Training

This pipeline trains an improved SILVAMANG AI species classifier using EfficientNet-B0 transfer learning.

It does not replace the existing baseline CNN automatically.

## Dataset

Expected dataset folders:

```text
dataset/processed/cnn_classification/train
dataset/processed/cnn_classification/val
dataset/processed/cnn_classification/test
```

Classes are read from folder names using `torchvision.datasets.ImageFolder`.

The exact class order is saved to:

```text
silvamang_ai_service/models/cnn_classifier/class_order.json
```

## Train

```powershell
cd C:\laragon\www\SilvaMang-AI

python silvamang_ai_service/training/cnn_classifier/train_efficientnet_transfer.py --epochs 30 --batch-size 16 --image-size 224 --model efficientnet_b0
```

Outputs:

```text
silvamang_ai_service/models/cnn_classifier/efficientnet_b0_best.pth
silvamang_ai_service/models/cnn_classifier/class_order.json
silvamang_ai_service/reports/efficientnet_transfer/training_history.csv
silvamang_ai_service/reports/efficientnet_transfer/val_metrics.json
```

## Evaluate

```powershell
cd C:\laragon\www\SilvaMang-AI

python silvamang_ai_service/training/cnn_classifier/evaluate_efficientnet_transfer.py
```

Outputs:

```text
silvamang_ai_service/reports/efficientnet_transfer/confusion_matrix.png
silvamang_ai_service/reports/efficientnet_transfer/classification_report.csv
silvamang_ai_service/reports/efficientnet_transfer/test_metrics.json
```

## Notes

- Uses ImageNet normalization.
- Uses training augmentation: `RandomResizedCrop`, `RandomHorizontalFlip`, `RandomRotation`, and `ColorJitter`.
- Uses class weights in `CrossEntropyLoss` to reduce class imbalance impact.
- Uses AdamW optimizer.
- Uses `ReduceLROnPlateau`.
- Uses early stopping based on validation macro F1.
- Does not modify dataset images.
- Does not retrain or delete the baseline CNN.
