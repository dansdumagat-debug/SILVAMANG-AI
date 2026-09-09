# APK Build Verification

## Commands

```powershell
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat analyze
& C:\flutter\bin\flutter.bat build apk --debug
```

Optional release build:

```powershell
& C:\flutter\bin\flutter.bat build apk --release
```

## APK Locations

- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-release.apk`

## Checklist

- [ ] APK builds successfully
- [ ] APK installs on Android phone
- [ ] `API_BASE_URL` is correct
- [ ] Camera permission works
- [ ] Location permission works
- [ ] Login works
- [ ] Capture works
- [ ] Save record works
- [ ] Offline queue works

## Physical Phone Note

For physical phone testing, Laravel must run on host `0.0.0.0` or be reachable through LAN if needed.

Example API URL:

```text
http://YOUR_COMPUTER_LAN_IP:8000/api
```
