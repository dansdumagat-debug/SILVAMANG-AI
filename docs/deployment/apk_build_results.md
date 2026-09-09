# APK Build Results

## Build Commands

Debug APK:

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat build apk --debug
```

Release APK:

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat build apk --release
```

## Expected Output Paths

Debug:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Release:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Result Log

- Build date:
- Build type:
- APK path:
- Build result:
- Notes:

## Physical Device Testing Notes

For real Android phone testing:

- Laravel API must be reachable through LAN IP.
- Flutter `API_BASE_URL` must use computer LAN IP, not `127.0.0.1`.
- Python AI service must also be reachable by Laravel.
- Camera and location permissions must be allowed on the phone.

Do not write fake build results.
