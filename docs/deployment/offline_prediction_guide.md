# SILVAMANG AI Offline Prediction Guide

Offline prediction means the Flutter app can classify a selected mangrove image on the phone even when Laravel, Python FastAPI, or the network is unavailable.

## Online vs Offline Prediction

Online prediction:

```text
Flutter -> Laravel /api/ai/predict -> Python FastAPI -> EfficientNet-B0
```

Expected online response:

```text
Mode: CNN EfficientNet-B0
Source: Python AI Service
```

Offline prediction:

```text
Flutter -> bundled ONNX EfficientNet-B0 model
```

Offline prediction uses ONNX inside Flutter and runs on Android/native mobile.
It is not supported on web/Chrome.

For local testing, run the Flutter app on the physical Android phone. Do not
run the offline ONNX flow on Chrome/web because ONNX Runtime uses native mobile
runtime support in this project.

Offline ONNX uses `flutter_onnxruntime` with one release model:

```text
assets/models/efficientnet_b0_silvamang_single.onnx
```

The model is loaded alone. The older `.onnx` plus `.onnx.data` pair is not a
runtime fallback and is not bundled in `pubspec.yaml`; this prevents a new
`class_order.json` from being used with a stale model.

If the app reports `Session creation failed`, common causes are an unsupported
ONNX opset/model format, a missing or zero-byte single-file asset, or an ONNX
input shape other than `[1, 3, 224, 224]`. Offline ONNX works only on native
Android in this project, not Chrome/Web.

Open this screen in the app to verify the offline model setup:

```text
Profile > Offline Model Diagnostic
```

The diagnostic screen checks class order loading, the selected model asset,
model file size, session creation, model inputs/outputs, and a dummy inference
attempt.

Expected offline response:

```text
Mode: Offline EfficientNet-B0
Source: On-device Flutter model
```

The app tries online prediction first. If the device has no connection or the server is unavailable, it runs the ONNX model on-device.

## Android Build Requirement

ONNX Runtime and recent Flutter Android plugins require Android `compileSdk` 36 or later.

This project uses:

```text
compileSdk 36
```

The app module and Android library subprojects are configured to compile with SDK 36 so ONNX/offline dependencies and current Flutter plugins can build.

The app uses `flutter_onnxruntime` for offline prediction. The old
`third_party/onnxruntime` copy is not the active runtime dependency.

Install Android SDK Platform 36 and Build Tools 36.0.0 before building on Android. You can install them from Android Studio SDK Manager or run:

```powershell
cd C:\laragon\www\SilvaMang-AI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\install_android_sdk_36.ps1
```

## Why Flutter Cannot Use `.pth` Directly

The trained model file `efficientnet_b0_best.pth` is a PyTorch checkpoint. Flutter cannot run PyTorch checkpoints directly. The model must be exported to ONNX, then loaded by ONNX Runtime in Flutter.

## Export a Staged ONNX Model

Train and evaluate a versioned experiment first. Then export its completed training run:

```powershell
cd C:\laragon\www\SilvaMang-AI
python .\silvamang_ai_service\training\cnn_classifier\export_staged_efficientnet_to_onnx.py `
  --source-run-dir .\silvamang_ai_service\artifacts\efficientnet_transfer\run-<timestamp>
```

This creates a matching model and label bundle inside the experiment only:

```text
<source-run-dir>/exports/efficientnet_b0_silvamang_single.onnx
<source-run-dir>/exports/class_order.json
<source-run-dir>/exports/export_manifest.json
```

It does not modify Flutter assets.

## Explicitly Promote an Evaluated Bundle

After reviewing held-out evaluation, export and promote in one explicit command:

```powershell
cd C:\laragon\www\SilvaMang-AI
python .\silvamang_ai_service\training\cnn_classifier\export_staged_efficientnet_to_onnx.py `
  --source-run-dir .\silvamang_ai_service\artifacts\efficientnet_transfer\run-<timestamp> `
  --output-dir .\silvamang_ai_service\artifacts\efficientnet_transfer\promotion-<version> `
  --evaluation-run-dir .\silvamang_ai_service\artifacts\efficientnet_transfer\run-<timestamp>\evaluations\evaluation-<timestamp> `
  --min-accuracy 0.85 `
  --min-macro-f1 0.80 `
  --min-per-class-precision 0.60 `
  --min-per-class-recall 0.60 `
  --min-per-class-f1 0.60 `
  --min-per-class-support 20 `
  --promote-to-flutter
```

The thresholds are explicit release inputs; choose the approved values. Promotion verifies
the evaluation report hashes, source checkpoint and label hashes, unchanged staged dataset
fingerprint, 224 input size, exact class order, and every per-class gate including `unknown`.
The staged 30-image-per-class minimum is a build floor. With a 10% test split, the example
support gate of 20 requires roughly 200 independent images in every class.

The promotion flag replaces these two Flutter assets as one matching pair:

```text
silvamang_mobile/assets/models/efficientnet_b0_silvamang_single.onnx
silvamang_mobile/assets/models/class_order.json
```

Promote the server checkpoint from the same source and evaluation runs. Stop the Python service
while replacing the active pair, restart it, then verify `GET /ai/health` reports CNN available,
image size 224, and the expected class order and hashes. Run Laravel's
`species:sync-cnn-support <class_order.json>` as a dry run and then with `--apply`. On this
Windows setup, invoke Artisan with
`& 'C:\laragon\bin\php\php-8.1.10-Win32-vs16-x64\php.exe' artisan ...` because bare `php` is
not on PowerShell's PATH. Rebuild and release Flutter only after those checks so the server,
database catalog, and app share one class order.

## Flutter Commands

Run:

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat pub get
& C:\flutter\bin\flutter.bat analyze
& C:\flutter\bin\flutter.bat run
```

## Android Build Requirement

The offline ONNX Runtime feature uses Android plugin modules such as
`flutter_onnxruntime` and `objectbox_flutter_libs`. Some of those modules
declare older Android SDK values internally, so the Flutter Android Gradle
configuration forces Android application and library modules to compile with
SDK 36. Make sure Android SDK Platform 36 is installed in Android Studio SDK
Manager before running on a phone.

## Testing Steps

1. Start Laragon/MySQL.
2. Start Laravel backend.
3. Start Python FastAPI.
4. Run the Flutter app on the phone.
5. Login.
6. Capture or select a mangrove image.
7. Continue to Identification.
8. Confirm online mode:

```text
Mode: CNN EfficientNet-B0
Source: Python AI Service
Image Count: 1
```

9. Stop Laravel.
10. Scan again.
11. Confirm offline mode:

```text
Mode: Offline EfficientNet-B0
Source: On-device Flutter model
Image Count: 1
```

If both online and offline prediction fail, the app shows:

```text
Prediction failed. Please check the image and try again.
```

It should not show mock species confidence or Top-K predictions unless a valid online or offline CNN result exists.
