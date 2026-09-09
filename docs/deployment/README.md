# SILVAMANG AI Deployment Documentation

This folder prepares SILVAMANG AI for local demo, APK build, capstone defense testing, and future deployment.

## Guides

- [Local Demo Guide](local_demo_guide.md)
- [Laravel Backend Deployment Guide](laravel_backend_deployment.md)
- [Flutter APK Build Guide](flutter_apk_build_guide.md)
- [Python AI Service Deployment Guide](python_ai_service_deployment.md)
- [Database Backup and Restore Guide](database_backup_restore.md)
- [Environment Variables Guide](environment_variables.md)
- [Demo Accounts Guide](demo_accounts.md)
- [Field Distance Measurement Guide](field_distance_measurement_guide.md)
- [Map Records and Offline Mapping Guide](map_records_and_offline_mapping_guide.md)
- [Pre-Defense Checklist](pre_defense_checklist.md)
- [Known Limitations](known_limitations.md)

## Verification Scripts

- `scripts/check_laravel_routes.ps1`
- `scripts/check_flutter_analyze.ps1`
- `scripts/check_python_ai_service.ps1`
- `scripts/start_local_demo_notes.md`

These scripts are lightweight checks only. They do not start long-running servers automatically.

## Phase 24B - Demo Build and Local Deployment Verification

Created:
- Demo build verification document
- Manual demo script
- Local startup checklist
- APK build verification document
- Troubleshooting guide
- Demo status report template
- Static verification script
- Debug APK build script

Current status:
Ready for local demo verification.

Next phase:
Phase 24C will run the actual demo verification checklist and build the debug APK.

## Phase 24C - Actual Demo Verification and APK Build

Created:
- Demo verification results template
- APK build results document
- Final demo checklist
- Static check script
- Debug APK build script
- PowerShell execution-policy troubleshooting notes

Manual verification commands:

Run static checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\check_all_static.ps1
```

Build debug APK:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\build_debug_apk.ps1
```

Next phase:
Phase 25 will prepare final documentation and defense materials.

## Local Demo Command Scripts

Run scripts from the project root:

```powershell
cd C:\laragon\www\SilvaMang-AI
```

Available scripts:

- `docs/deployment/scripts/set_flutter_api_url.ps1`
- `docs/deployment/scripts/start_python_ai_service.ps1`
- `docs/deployment/scripts/start_laravel_backend.ps1`
- `docs/deployment/scripts/run_flutter_phone.ps1`
- `docs/deployment/scripts/build_debug_apk_local.ps1`
- `docs/deployment/scripts/start_demo_windows.ps1`

Run any script with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script_path>
```

Examples:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\set_flutter_api_url.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\start_demo_windows.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\run_flutter_phone.ps1
```

If PowerShell blocks scripts, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\<script>.ps1
```

Step-by-step guide:

```text
docs/deployment/run_commands_step_by_step.md
```

## Running Laravel and Flutter on Android Phone

Use these scripts from the project root:

```powershell
cd C:\laragon\www\SilvaMang-AI
```

Scripts:

- `docs/deployment/scripts/set_flutter_api_url_for_phone.ps1`
- `docs/deployment/scripts/start_python_ai_service.ps1`
- `docs/deployment/scripts/start_laravel_backend_phone.ps1`
- `docs/deployment/scripts/allow_laravel_firewall_port_8000.ps1`
- `docs/deployment/scripts/check_android_phone_connection.ps1`
- `docs/deployment/scripts/run_flutter_on_phone.ps1`
- `docs/deployment/scripts/show_phone_test_urls.ps1`

Run scripts with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script_path>
```

If PowerShell blocks scripts, use ExecutionPolicy Bypass:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\<script>.ps1
```

Full phone guide:

```text
docs/deployment/run_laravel_flutter_on_phone_guide.md
```
## Connecting Flutter to Laravel Outside the Same Wi-Fi

Use a public tunnel when the Android phone and laptop are not on the same local Wi-Fi.
Expose Laravel only; Flutter should still call Laravel, and Laravel should call Python locally.

Scripts:

- `docs/deployment/scripts/set_flutter_api_url_custom.ps1`
- `docs/deployment/scripts/start_laravel_for_tunnel.ps1`
- `docs/deployment/scripts/start_python_ai_service.ps1`

Run scripts with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\<script-name>.ps1
```

Full guide:

```text
docs/deployment/connect_flutter_to_laravel_outside_same_wifi.md
```
## Testing with ngrok

Use ngrok when the Android phone and laptop are not on the same Wi-Fi. Flutter should connect to Laravel through the ngrok HTTPS URL, and Laravel should continue calling Python locally through `AI_SERVICE_URL=http://127.0.0.1:9000`.

Scripts:

- `docs/deployment/scripts/start_python_ai_for_ngrok.ps1`
- `docs/deployment/scripts/start_laravel_for_ngrok.ps1`
- `docs/deployment/scripts/set_flutter_api_url_ngrok.ps1`
- `docs/deployment/scripts/test_local_services_before_ngrok.ps1`
- `docs/deployment/scripts/test_ngrok_api_url.ps1`

Command summary:

1. Start Python.
2. Start Laravel.
3. Run `ngrok http 8000`.
4. Set Flutter API URL to the ngrok URL ending in `/api`.
5. Run Flutter on the Android phone.

Full guide:

```text
docs/deployment/ngrok_flutter_laravel_testing_guide.md
```
