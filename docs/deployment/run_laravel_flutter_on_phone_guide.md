# Run SILVAMANG AI on Android Phone

## Step 1 - Start Laragon

Open Laragon and click Start All.
Make sure MySQL is running.

## Step 2 - Set Flutter API URL

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\set_flutter_api_url_for_phone.ps1
```

Use laptop IPv4 address from:

```powershell
ipconfig
```

Example:

```text
API_BASE_URL=http://192.168.1.12:8000/api
```

## Step 3 - Start Python AI

Open Terminal 1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_python_ai_service.ps1
```

## Step 4 - Start Laravel

Open Terminal 2:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_laravel_backend_phone.ps1
```

## Step 5 - Test Phone Browser

On cellphone browser, open:

```text
http://YOUR_PC_IP:8000/api/health
http://YOUR_PC_IP:8000/api/ai/service-health
```

If the phone cannot open `/api/health`, run PowerShell as Administrator on the
laptop and allow port 8000:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\allow_laravel_firewall_port_8000.ps1
```

## Step 6 - Check Android Phone Connection

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\check_android_phone_connection.ps1
```

## Step 7 - Run Flutter On Phone

Open Terminal 3:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\run_flutter_on_phone.ps1
```

## Step 8 - Test Online Identification

In the app:

```text
Login
Capture / Identify
Select image
Choose plant part
Continue to Identification
```

Expected:

```text
Mode: CNN EfficientNet-B0
Source: python_ai_service
Image Count: 1
```

## Step 9 - Test Offline Identification

Stop Laravel only.
Scan again.

Expected:

```text
Mode: Offline EfficientNet-B0
Source: flutter_offline_model
```

## Common Issues

- Phone cannot open API: same Wi-Fi required, Laravel must run on `0.0.0.0`.
- Phone still cannot open API: allow Windows Firewall inbound TCP port `8000`.
- App still uses old URL: rerun Flutter on the phone after changing `.env`.
- Login fails: check MySQL in Laragon.
- Prediction fallback: check Python AI and Laravel are running.
- Chrome build fails: do not run Chrome because ONNX uses native runtime.
- Barangay unavailable: provide `barangay_boundaries.geojson`.
