# Testing Flutter and Laravel Using ngrok

## Purpose

Use ngrok when the phone and laptop are not on the same Wi-Fi.

## Required Terminals

Terminal 1 - Python AI:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_python_ai_for_ngrok.ps1
```

Terminal 2 - Laravel:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_laravel_for_ngrok.ps1
```

Terminal 3 - ngrok:

```powershell
ngrok http 8000
```

Terminal 4 - Set Flutter API URL:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\set_flutter_api_url_ngrok.ps1
```

Terminal 5 - Flutter Android:

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat run -d AF2SVB3703003164
```

## Important Setup

Flutter `API_BASE_URL` must be:

```text
https://YOUR-NGROK-URL/api
```

Laravel `.env` should keep:

```env
AI_SERVICE_URL=http://127.0.0.1:9000
```

## Do Not Expose Python Directly

Python should stay local. Laravel calls Python.

## Test Before Running Flutter

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\test_local_services_before_ngrok.ps1
```

Then:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\test_ngrok_api_url.ps1
```

## Expected Flutter Online Result

```text
Mode: CNN EfficientNet-B0
Source: python_ai_service
Image Count: 1
```

## Common Problems

1. ngrok URL changes every restart on free plan.
   Fix: rerun `set_flutter_api_url_ngrok.ps1` after every new ngrok URL.

2. Login fails.
   Fix: Start Laragon/MySQL and seed database if needed.

3. Prediction falls back to mock.
   Fix: Make sure Python AI service is running and Laravel `AI_SERVICE_URL` is correct.

4. Flutter cannot build.
   Fix Flutter analyzer/build errors first. ngrok cannot fix Flutter code errors.

5. Offline prediction still fails.
   This is unrelated to ngrok. Offline uses ONNX inside Flutter.
