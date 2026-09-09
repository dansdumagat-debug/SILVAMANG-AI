# CNN Species Classification Baseline

Purpose:
This folder contains the baseline CNN pipeline for SILVAMANG AI species classification.

Current phase:
Pipeline preparation only.

Workflow:
1. Add real mangrove images to dataset/raw/
2. Validate dataset
3. Split dataset
4. Train baseline CNN
5. Evaluate model
6. Review metrics
7. Use trained model in later AI service phase

Commands:

Install optional CNN dependencies:

```bash
pip install -r silvamang_ai_service/requirements-cnn.txt
```

Dry-run dataset split:

```bash
python silvamang_ai_service/training/cnn_classifier/dataset_split.py
```

Apply dataset split:

```bash
python silvamang_ai_service/training/cnn_classifier/dataset_split.py --apply
```

Train baseline:

```bash
python silvamang_ai_service/training/cnn_classifier/train_cnn_baseline.py --epochs 10
```

Evaluate:

```bash
python silvamang_ai_service/training/cnn_classifier/evaluate_cnn_baseline.py
```

Predict one image:

```bash
python silvamang_ai_service/training/cnn_classifier/predict_cnn_baseline.py --image path/to/image.jpg
```

Metrics:
- accuracy
- precision
- recall
- F1-score
- top-3 accuracy
- confusion matrix

Important:
Do not use the test set during training.
