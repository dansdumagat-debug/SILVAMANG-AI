# Troubleshooting Guide

## 1. PHP Not Recognized

Use Laragon PHP directly:

```powershell
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan route:list
```

## 2. Flutter Not in PATH

Use the full Flutter path:

```powershell
& C:\flutter\bin\flutter.bat analyze
```

## 3. Python Activate.ps1 Blocked

Run Python from the virtual environment without activating:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

## 4. Android Phone Cannot Connect to Backend

Use the computer LAN IP instead of `127.0.0.1` or `10.0.2.2`.

Example:

```text
http://192.168.1.10:8000/api
```

Also check Windows Firewall and make sure phone and computer are on the same Wi-Fi.

## 5. Android Emulator Cannot Connect

Use:

```text
http://10.0.2.2:8000/api
```

## 6. CNN Unavailable

Check:

```text
silvamang_ai_service/models/cnn_classifier/baseline_cnn.pth
```

Also check the Python `/health` response.

## 7. YOLO Unavailable

This is an expected limitation. YOLO is pending annotation/training.

## 8. Measurement Still Mock

This is an expected limitation. MiDaS/depth estimation is not yet fully integrated.

## 9. Login Logs Out Immediately

Check:

- Laravel `/api/me` is reachable.
- The saved token is valid.
- Persistent login/offline session behavior is enabled.
- A 401/403 response clears invalid tokens.
- Network failure should not clear a valid cached session.

## 10. Image Upload Fails

Check Laravel storage link:

```powershell
php artisan storage:link
```

Also check:

- `FILESYSTEM_DISK=public`
- `storage/app/public` permissions
- Max upload size in PHP configuration

## PowerShell Script Execution Blocked

Problem:

PowerShell may show:

```text
cannot be loaded because running scripts is disabled on this system
```

Fix option 1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\check_all_static.ps1
```

Fix option 2:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\docs\deployment\scripts\check_all_static.ps1
```

Use `Scope Process` to avoid permanently changing the system policy.
