# Start Local Demo Notes

Use three PowerShell terminals:

1. Laravel backend
2. Python AI service
3. Flutter mobile app

Do not create or use scripts that keep servers running automatically for this phase.

## Terminal 1 - Laravel Backend

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan serve
```

## Terminal 2 - Python AI Service

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_ai_service
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

## Terminal 3 - Flutter Mobile App

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat run -d chrome
```
