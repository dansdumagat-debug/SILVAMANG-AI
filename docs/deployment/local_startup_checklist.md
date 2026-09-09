# Local Startup Checklist

Use three terminals for a local demo.

## Terminal 1 - Python AI Service

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_ai_service
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

Check:

```text
http://127.0.0.1:9000/health
http://127.0.0.1:9000/docs
```

## Terminal 2 - Laravel Backend

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan serve
```

Check:

```text
http://127.0.0.1:8000/api/health
http://127.0.0.1:8000/admin
```

## Terminal 3 - Flutter

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat run -d chrome
```

## API URL Notes

- Android emulator API URL: `http://10.0.2.2:8000/api`
- Real Android phone API URL: `http://YOUR_COMPUTER_LAN_IP:8000/api`

For physical phone testing, the phone and computer must be on the same Wi-Fi network.
