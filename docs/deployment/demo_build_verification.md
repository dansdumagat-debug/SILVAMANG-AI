# Demo Build Verification

## 1. Purpose

Use this checklist to verify SILVAMANG AI before local demo, defense presentation, or APK handoff.

## 2. Verification Date

- Date:

## 3. Verified By

- Name:
- Role:

## 4. Laravel Backend Checks

- [ ] `php artisan route:list` works
- [ ] `/api/health` works
- [ ] `/api/ai/service-health` works
- [ ] `/api/ai/predict` works
- [ ] `/api/ai/measure` works
- [ ] `/api/ai/assistant/chat` works
- [ ] Admin login works

## 5. Python AI Service Checks

- [ ] `/health` works
- [ ] `/docs` works
- [ ] `cnn.available` is true
- [ ] `/predict` accepts image
- [ ] `/measure` returns measurement result

## 6. Flutter App Checks

- [ ] `flutter analyze` has no issues
- [ ] App opens
- [ ] Login works
- [ ] Persistent login works
- [ ] Offline session works
- [ ] Capture guide works
- [ ] Image upload works
- [ ] Prediction result works
- [ ] Save scan record works
- [ ] Records screen works
- [ ] AI assistant works
- [ ] Offline queue works

## 7. Database Checks

- [ ] MySQL is running
- [ ] `silvamang_ai` database exists
- [ ] Migrations are applied
- [ ] Demo accounts exist
- [ ] Scan records can be stored

## 8. Image Upload Checks

- [ ] Laravel public storage link exists
- [ ] Image upload endpoint accepts files
- [ ] Uploaded files are stored in public disk
- [ ] Record detail displays uploaded image metadata

## 9. CNN Prediction Checks

- [ ] CNN model file exists
- [ ] Python service reports CNN availability
- [ ] Prediction returns top species
- [ ] Prediction returns top-k results
- [ ] Flutter displays CNN prediction result

## 10. GPS/Location Validation Checks

- [ ] Location permission prompt appears
- [ ] GPS coordinates are captured or fallback coordinates are used
- [ ] Laravel location validation endpoint returns result
- [ ] Flutter displays validation status

## 11. AI Assistant Checks

- [ ] Chat screen opens
- [ ] Prompt can be submitted
- [ ] Assistant response appears
- [ ] Backend assistant logs are saved

## 12. Offline Queue Checks

- [ ] Offline queue page opens
- [ ] Offline save fallback creates queue item
- [ ] Refresh Status works
- [ ] Sync Now works when backend is reachable
- [ ] Clear Synced works

## 13. Admin Dashboard Checks

- [ ] Admin dashboard opens
- [ ] Species management opens
- [ ] Scan records review opens
- [ ] Dataset verification opens
- [ ] Reports and analytics opens
- [ ] AI assistant logs are visible

## 14. Known Issues

- Issue:
- Impact:
- Workaround:

## 15. Final Demo Readiness Status

- [ ] Ready for local demo
- [ ] Ready with minor issues
- [ ] Not ready

Notes:
