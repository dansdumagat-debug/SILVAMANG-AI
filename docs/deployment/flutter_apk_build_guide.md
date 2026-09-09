# Flutter APK Build Guide

## 1. Check Flutter Installation

```powershell
cd silvamang_mobile
& C:\flutter\bin\flutter.bat analyze
```

## 2. Check API Base URL

Open:

```text
silvamang_mobile/.env
```

Use:

- Emulator: `http://10.0.2.2:8000/api`
- Real phone: computer LAN IP, for example `http://192.168.1.10:8000/api`

Laravel and Python services must be reachable from the phone.

## 3. Android Permissions

The app may require permissions for:

- Camera
- Gallery/media access
- Location
- Internet

Check Android manifest files before release testing.

## 4. Build Debug APK

```powershell
cd silvamang_mobile
& C:\flutter\bin\flutter.bat build apk --debug
```

Debug APK path:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## 5. Build Release APK

```powershell
cd silvamang_mobile
& C:\flutter\bin\flutter.bat build apk --release
```

Release APK path:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 6. Install APK on Android Phone

Copy the APK to the phone or use ADB:

```powershell
adb install build/app/outputs/flutter-apk/app-debug.apk
```

For physical phone testing, update `.env` before building so `API_BASE_URL` uses the computer LAN IP.

## 7. Common Issues

### Unable to connect to server

- Use LAN IP, not `127.0.0.1`, on a real phone.
- Make sure Laravel is started with a host reachable from the phone if needed.
- Check Windows Firewall.

### Plugin symlink errors on Windows

Developer Mode may be needed on Windows for plugin symlinks.

### Release APK cannot access local API

Confirm the phone and computer are on the same Wi-Fi network and the API URL is not localhost.
