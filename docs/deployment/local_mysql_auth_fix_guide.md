# SILVAMANG AI Local MySQL and Auth Fix Guide

Use this guide when Laravel login returns a database connection error and `/api/ai/predict` returns `Unauthenticated.`

## Step 1: Start Laragon

Open Laragon and click **Start All**.

This must start MySQL before Laravel login can work.

## Step 2: Fix Laravel MySQL Setup

From the project root:

```powershell
cd C:\laragon\www\SilvaMang-AI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\fix_laravel_mysql_local.ps1
```

This script:

- checks MySQL
- creates `silvamang_ai` if missing
- clears Laravel config/cache
- runs migrations
- runs seeders
- checks migration status

It does not delete or reset the database.

## Step 3: Start Laravel

Open a new PowerShell window:

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan serve --host=0.0.0.0 --port=8000
```

Keep this terminal open.

## Step 4: Test Login

Open another PowerShell window from the project root:

```powershell
cd C:\laragon\www\SilvaMang-AI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\test_api_login_local.ps1
```

Expected:

```text
Login succeeded
Token received: YES
```

The token is not printed.

## Step 5: Make Sure Python AI Is Running

Open another PowerShell window:

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_ai_service
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

Keep this terminal open.

Check:

```text
http://127.0.0.1:9000/health
```

## Step 6: Test Laravel AI Prediction

From the project root:

```powershell
cd C:\laragon\www\SilvaMang-AI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\test_laravel_ai_predict_local.ps1
```

Expected output:

```text
response mode: cnn_efficientnet_b0
response source: python_ai_service
received.image_count: 1
top_prediction.scientific_name: <predicted class>
```

## Local Demo Users

The seeders prepare these local demo users:

```text
user@silvamang.test
admin@silvamang.test
researcher@silvamang.test
```

Use the local demo password configured by the seeder. Change demo passwords before any real deployment.

## Common Problems

If login fails with a database connection message:

1. Open Laragon.
2. Click **Start All**.
3. Run `fix_laravel_mysql_local.ps1` again.
4. Restart Laravel if it was already running.

If `/api/ai/predict` returns `Unauthenticated.`:

1. Login is failing or no token was received.
2. Run `test_api_login_local.ps1`.
3. Fix MySQL first before testing prediction.

If prediction returns fallback:

1. Make sure Python AI is running on `http://127.0.0.1:9000`.
2. Test `http://127.0.0.1:9000/health`.
3. Run `test_laravel_ai_predict_local.ps1` again.
