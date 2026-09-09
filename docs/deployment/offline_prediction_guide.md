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

Offline ONNX now uses `flutter_onnxruntime` and prefers the single-file model:

```text
assets/models/efficientnet_b0_silvamang_single.onnx
```

The single-file model is loaded alone. Do not add or require
`efficientnet_b0_silvamang_single.onnx.data`.

If the single-file asset is unavailable, the app falls back to the older paired
ONNX export:

```text
assets/models/efficientnet_b0_silvamang.onnx
assets/models/efficientnet_b0_silvamang.onnx.data
```

Both fallback files must be bundled as Flutter assets. At runtime, the app
copies both files to device storage with the exact filenames:

```text
efficientnet_b0_silvamang.onnx
efficientnet_b0_silvamang.onnx.data
```

The files must sit side by side before ONNX Runtime creates the session because
the `.onnx` model references the external `.onnx.data` file.

If the external `.onnx.data` file is missing or cannot be copied beside the
model file on device storage, offline prediction will fail with a clear model
loading error. In that case, export a single-file ONNX model and use:

```text
assets/models/efficientnet_b0_silvamang_single.onnx
```

If the app reports `Session creation failed`, ONNX Runtime could not load the
copied model file. Common causes are an unsupported ONNX opset/model format, a
missing external `.onnx.data` file, a zero-byte copied file, or the data file not
being copied side-by-side with the `.onnx` file on device storage.

For mobile, a single-file ONNX model is preferred when available:

```text
assets/models/efficientnet_b0_silvamang_single.onnx
```

If that asset exists and is declared in `silvamang_mobile/pubspec.yaml`, the
Flutter offline prediction service will prefer it. Otherwise it uses the
`.onnx` plus `.onnx.data` pair.

The Flutter project declares the `assets/models/` folder so the existing paired
model files and a future `efficientnet_b0_silvamang_single.onnx` export are all
bundled. Offline ONNX works only on native Android in this project, not
Chrome/Web.

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

## Export ONNX Model

Run:

```powershell
cd C:\laragon\www\SilvaMang-AI
python .\silvamang_ai_service\export\export_efficientnet_to_onnx.py
```

This creates:

```text
silvamang_mobile/assets/models/efficientnet_b0_silvamang.onnx
silvamang_mobile/assets/models/efficientnet_b0_silvamang.onnx.data
silvamang_mobile/assets/models/class_order.json
```

## Export Single-File ONNX Model

Run:

```powershell
cd C:\laragon\www\SilvaMang-AI
python .\silvamang_ai_service\export\export_efficientnet_to_onnx_single_file.py
```

This creates:

```text
silvamang_mobile/assets/models/efficientnet_b0_silvamang_single.onnx
silvamang_mobile/assets/models/class_order.json
```

After creating the single-file model, add it to `silvamang_mobile/pubspec.yaml`
under Flutter assets:

```yaml
- assets/models/efficientnet_b0_silvamang_single.onnx
```

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
