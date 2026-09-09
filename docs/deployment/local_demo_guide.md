# SILVAMANG AI Local Demo Guide

Use separate Windows PowerShell terminals for Laravel, Python AI service, and Flutter.

## 1. Required Tools

- Laragon with MySQL running
- PHP and Composer
- Python 3
- Flutter SDK
- Chrome, Android emulator, or physical Android phone

## 2. Start MySQL/Laragon

Open Laragon and start Apache/Nginx and MySQL. Confirm the database exists:

```powershell
mysql -u root -p -e "SHOW DATABASES;"
```

Expected database:

```text
silvamang_ai
```

## 3. Start Laravel Backend

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan serve
```

Default local API:

```text
http://127.0.0.1:8000/api
```

## 4. Start Python AI Service

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_ai_service
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

AI service URL:

```text
http://127.0.0.1:9000
```

## 5. Run Flutter App

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat run -d chrome
```

API base URL notes:

- Android emulator: `http://10.0.2.2:8000/api`
- Physical Android phone: use the computer LAN IP, for example `http://192.168.1.10:8000/api`
- Browser on same computer: `http://127.0.0.1:8000/api`

## 6. Test Admin Dashboard

Open:

```text
http://127.0.0.1:8000/admin/login
```

Use the demo admin account only for local testing.

## 7. Test API Health

```powershell
curl.exe http://127.0.0.1:8000/api/health
```

## 8. Test AI Service Health

```powershell
curl.exe http://127.0.0.1:9000/health
```

## 9. Test CNN Prediction

Open:

```text
http://127.0.0.1:9000/docs
```

Use `POST /predict` with a sample mangrove image. CNN availability depends on:

```text
silvamang_ai_service/models/cnn_classifier/baseline_cnn.pth
```

## 10. Test Image Upload

In the Flutter app:

1. Open Capture Guide.
2. Select or capture plant-part images.
3. Continue to the identification result.
4. Save the scan record.
5. Confirm images appear in record details and admin scan review.

## 11. Test GPS/Location Validation

In the Flutter app:

1. Allow location permission.
2. Save a scan record.
3. Confirm validation result appears.
4. Use record detail revalidation if available.

## 12. Test AI Assistant

In the Flutter app:

1. Open AI Assistant.
2. Ask a mangrove-related question.
3. Confirm response appears.

## 13. Test Offline Queue

1. Stop Laravel or disconnect the app from the API.
2. Save a scan or action that supports offline fallback.
3. Open Offline Queue.
4. Restore connection.
5. Use Refresh Status and Sync Now.

## 14. Common Errors and Fixes

### Unable to connect to SILVAMANG AI server

- Laravel may not be running.
- The phone may be using `127.0.0.1`, which points to the phone itself.
- Use the computer LAN IP for physical Android devices.
- Allow PHP/Laragon through Windows Firewall.

### Database connection failed

- Start MySQL in Laragon.
- Check Laravel `.env` database settings.
- Confirm `silvamang_ai` exists.

### Python AI service unavailable

- Start the FastAPI service manually.
- Check `AI_SERVICE_URL=http://127.0.0.1:9000`.
- Install Python dependencies.

### Flutter plugin symlink issue on Windows

- Enable Windows Developer Mode.
- Run `flutter pub get` again.
