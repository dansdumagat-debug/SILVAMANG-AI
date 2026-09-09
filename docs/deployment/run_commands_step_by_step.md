# SILVAMANG AI Local Demo Commands

Run these commands from:

```powershell
cd C:\laragon\www\SilvaMang-AI
```

## Step 1: Start Laragon and MySQL

Open Laragon manually and start MySQL.

## Step 2: Set Flutter API URL

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\set_flutter_api_url.ps1
```

Enter your laptop IPv4 address, for example:

```text
192.168.1.12
```

The script updates:

```text
silvamang_mobile\.env
```

## Step 3: Start Python AI Service

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_python_ai_service.ps1
```

Keep this terminal open.

## Step 4: Start Laravel Backend

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_laravel_backend.ps1
```

Keep this terminal open.

## Step 5: Test on Cellphone Browser

Replace `YOUR_PC_IP` with your laptop IPv4 address:

```text
http://YOUR_PC_IP:8000/api/health
http://YOUR_PC_IP:8000/api/ai/service-health
```

If these do not open on the phone, check Wi-Fi, firewall, and the API URL.

## Step 6: Run Flutter on Phone

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\run_flutter_phone.ps1
```

The phone must have USB debugging enabled. Choose the Android phone if Flutter asks.

## Step 7: Scan/Predict Flow

1. Login
2. Home
3. Capture Guide
4. Select image
5. Continue to Identification
6. Check Mode: CNN Baseline
7. Check Source: python_ai_service
8. Save Record
