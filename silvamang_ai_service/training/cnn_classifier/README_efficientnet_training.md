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

Classes are read from folder names using `torchvision.datasets.ImageFolder`. Every requested
split must contain the same non-empty class folders. If the dataset root contains
`class_order.json`, training and evaluation enforce it exactly before loading the model.

Training writes the exact class order into its isolated experiment run. It does not write to
the active server or Flutter model directories.

### Versioned 29-class dataset

For the 28-species plus `unknown` experiment, first build a reviewed versioned dataset by
following `README_staged_29_dataset.md`. Pass that version directory as `--dataset-root`.
The trainer enforces the builder's `class_order.json` and `BUILD_COMPLETE.json` contract.
For this 29-class workflow, all five builder artifacts are mandatory:
`BUILD_COMPLETE.json`, `dataset_manifest.csv`, `config_snapshot.json`,
`class_order.json`, and `build_report.json`. Removing any of them cannot downgrade the
dataset into a legacy run. The completion marker hashes the other four artifacts, and the
consumer verifies their input-manifest snapshots, approval lineage, source grouping, rights,
and staged image hashes before training.
It hashes every file in that completed dataset before training and checks the same fingerprint
again after training, during evaluation, and before either server or Flutter promotion. Do not
edit, add, or remove an image or manifest file inside a staged version after training starts.

### Future unknown class preparation

The reserved `unknown` folders and curation guidance are documented in:

```text
docs/ai/unknown_class_dataset.md
```

The proposed 11-class order is stored separately from the active runtime mapping:

```text
silvamang_ai_service/training/cnn_classifier/future_11_class_config.json
```

This future configuration appends `unknown` at index 10. Keep the deployed checkpoint and its
active class-order file at the same output count until a replacement bundle is evaluated and
explicitly promoted.

The placeholder `unknown` folders are empty. Populate `train`, `val`, and `test` before starting an 11-class training run because `torchvision.datasets.ImageFolder` rejects empty class folders. A future training run must produce and be deployed with a matching 11-entry `class_order.json`.

## Train

```powershell
cd C:\laragon\www\SilvaMang-AI

python silvamang_ai_service/training/cnn_classifier/train_efficientnet_transfer.py `
  --dataset-root dataset/staging/cnn_classification_29/2026-09-24-v1 `
  --epochs 30 `
  --batch-size 16 `
  --image-size 224 `
  --model efficientnet_b0
```

`--image-size` must be exactly `224`. The online Python service and the Flutter ONNX runtime
both use a 224 x 224 input after the same 256-pixel resize and center crop.

When `--run-dir` is omitted, the command creates a UTC timestamped run under:

```text
silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp>/
  checkpoints/efficientnet_b0_best.pth
  class_order.json
  reports/training_history.csv
  reports/val_metrics.json
  RUN_COMPLETE.json
```

Use `--run-dir <new-empty-directory>` to choose an explicit versioned run. The command refuses
non-empty run directories and active server or Flutter model directories.

Older experiments without a staged-builder bundle require the explicit
`--allow-legacy-dataset` option for both training and evaluation. That escape hatch is refused
for every 29-class dataset and every dataset containing `unknown`.

## Evaluate

```powershell
cd C:\laragon\www\SilvaMang-AI

python silvamang_ai_service/training/cnn_classifier/evaluate_efficientnet_transfer.py `
  --source-run-dir silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp> `
  --dataset-root dataset/staging/cnn_classification_29/2026-09-24-v1
```

Evaluation requires a completed training marker and verifies the test folders, checkpoint
classes, and class-order file. Its reports go into a separate timestamped evaluation run by
default. Use `--run-dir <new-empty-directory>` to choose that output location.
The completion marker hashes `class_order.json`, `test_metrics.json`,
`classification_report.csv`, and `confusion_matrix.png`; promotion refuses changed reports.

## Staged ONNX export

Export remains inside the completed experiment run by default:

```powershell
python silvamang_ai_service/training/cnn_classifier/export_staged_efficientnet_to_onnx.py `
  --source-run-dir silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp>
```

Outputs:

```text
<source-run-dir>/exports/efficientnet_b0_silvamang_single.onnx
<source-run-dir>/exports/class_order.json
<source-run-dir>/exports/export_manifest.json
```

Flutter assets are only replaced when `--promote-to-flutter` is supplied explicitly. That flag
also requires the completed evaluation run and every acceptance threshold shown below. The
exporter verifies the ONNX input is exactly `[1, 3, 224, 224]`, its output is `[1, class_count]`,
and it has no external tensor-data file.

```powershell
python silvamang_ai_service/training/cnn_classifier/export_staged_efficientnet_to_onnx.py `
  --source-run-dir silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp> `
  --output-dir silvamang_ai_service/artifacts/efficientnet_transfer/flutter-<version> `
  --evaluation-run-dir silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp>/evaluations/evaluation-<timestamp> `
  --min-accuracy 0.85 `
  --min-macro-f1 0.80 `
  --min-per-class-precision 0.60 `
  --min-per-class-recall 0.60 `
  --min-per-class-f1 0.60 `
  --min-per-class-support 20 `
  --promote-to-flutter
```

The threshold values are examples. Use the approved project acceptance criteria. Every
per-class gate includes the `unknown` class when it is present in `class_order.json`.
The staged builder's 30 unique images per class is only a build floor. For example, a 10%
held-out split needs roughly 200 independent images per class to satisfy
`--min-per-class-support 20`; a 30-image class can be built but cannot pass that example
deployment gate.

## Explicit server promotion

Promoting the PyTorch checkpoint is a separate command. It requires the completed evaluation
run, explicit acceptance thresholds, and the `--promote` acknowledgement:

```powershell
python silvamang_ai_service/training/cnn_classifier/promote_efficientnet_run.py `
  --source-run-dir silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp> `
  --evaluation-run-dir silvamang_ai_service/artifacts/efficientnet_transfer/run-<timestamp>/evaluations/evaluation-<timestamp> `
  --min-accuracy 0.85 `
  --min-macro-f1 0.80 `
  --min-per-class-precision 0.60 `
  --min-per-class-recall 0.60 `
  --min-per-class-f1 0.60 `
  --min-per-class-support 20 `
  --promote
```

The command verifies that training and evaluation used the same dataset version and exact
class order. It installs `efficientnet_b0_best.pth` and `class_order.json` as a pair and restores
the previous pair if either replacement fails. Choose the thresholds from the approved model
acceptance criteria; the example values are illustrative.

## Coordinated release after promotion

1. Stop or drain the running Python AI service before replacing the active checkpoint pair.
   The service caches the model and labels in memory, so a file copy alone does not reload it.
2. Run the explicit server promotion command, then restart the Python service.
3. Call `GET http://127.0.0.1:9000/ai/health`. Confirm `models.cnn` and
   `readiness.cnn.available` are `true`, `required_image_size` and `loaded_image_size` are 224,
   and `class_count`, `class_order`, `checkpoint_sha256`, and `class_order_sha256` match the
   promotion receipt. The overall status may remain `partial` when unrelated optional models
   are absent.
4. From `silvamang_api`, preview and then apply the database support flags using the exact
   promoted server label file:

   ```powershell
   & 'C:\laragon\bin\php\php-8.1.10-Win32-vs16-x64\php.exe' artisan species:sync-cnn-support ..\silvamang_ai_service\models\cnn_classifier\class_order.json
   & 'C:\laragon\bin\php\php-8.1.10-Win32-vs16-x64\php.exe' artisan species:sync-cnn-support ..\silvamang_ai_service\models\cnn_classifier\class_order.json --apply
   ```

5. Export/promote Flutter from the same training and evaluation runs with the same thresholds.
   Rebuild the APK/AAB, install it on a physical Android device, run **Offline Model
   Diagnostic**, and test known species plus `unknown` both online and offline.

The paired file installer verifies staged-copy hashes and restores the previous pair after a
normal copy or replacement failure. Promotion pins the hashes from the completed run, holds a
destination lock, preserves verified backup copies, and leaves a transaction journal when
cleanup or recovery needs operator attention. Receipt and manifest writes use atomic file
replacement. Because the active deployment still uses two fixed filenames, there remains a
narrow process or power-loss window between the two filesystem replaces; a generation-pointer
deployment would be required to eliminate it completely. Keep the service stopped during
promotion, retain the previous release artifacts, inspect any retained
`.artifact-promotion-*` journal or backup, and perform the restart and readiness checks before
returning traffic.

## Notes

- Uses ImageNet normalization.
- Uses training augmentation: `RandomResizedCrop`, `RandomHorizontalFlip`, `RandomRotation`, and `ColorJitter`.
- Uses class weights in `CrossEntropyLoss` to reduce class imbalance impact.
- Uses AdamW optimizer.
- Uses `ReduceLROnPlateau`.
- Uses early stopping based on validation macro F1.
- Does not modify dataset images.
- Does not retrain or delete the baseline CNN.
- Unknown-class preparation does not alter the current checkpoint or active runtime class order.
