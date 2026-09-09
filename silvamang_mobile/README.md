# SILVAMANG AI Mobile

Mobile application foundation for SILVAMANG AI.

Tagline: Identify. Measure. Protect.

## Phase 5 - Flutter Initialization and Design System

Created the Flutter foundation for future mobile features:

- App constants and environment placeholders
- Dark green, soft green, mint, white, and light gray theme
- Routing foundation with placeholder routes
- Reusable cards, buttons, fields, badges, metrics, empty states, and loading views
- Placeholder pages for authentication, capture, identification, measurement, location validation, assistant, records, species, map, and profile
- Mock models and mock data for future UI screens
- Service placeholders for API, storage, connectivity, and permissions

## Local Setup

```bash
flutter pub get
dart format lib
flutter analyze
```

## Environment

Copy `.env.example` to `.env` and update values for your device.

```env
API_BASE_URL=http://10.0.2.2:8000/api
APP_NAME=SILVAMANG AI
APP_TAGLINE=Identify. Measure. Protect.
```

Use `http://10.0.2.2:8000/api` for the Android emulator.
Use your computer LAN IP address for a physical phone.

## Current Limits

Laravel login is not integrated yet.
Camera, GPS, image upload, and AI prediction are placeholders only.

## Next Phase

Phase 6 should build the first real mobile workflow on top of this foundation.

## Phase 6C - Remaining Static Mobile Screens

Implemented:

- Records/history screen
- Species database screen
- Species detail screen
- AI assistant screen
- Monitoring map placeholder screen
- Profile screen

Next phase:
Phase 7 will connect Flutter authentication to the Laravel API.

## Phase 7 - Flutter Authentication Integration

Implemented:

- Auth response model
- User model
- Auth repository
- Auth controller/provider
- Token storage
- Dio authorization header
- Login form connected to Laravel API
- Register form connected to Laravel API
- Logout action
- Auth-aware splash behavior
- Profile user display

Backend API expected:

- POST `/api/login`
- POST `/api/register`
- POST `/api/logout`
- GET `/api/me`

Local API base URL:
`http://10.0.2.2:8000/api`

For real Android device testing, replace `API_BASE_URL` with the computer LAN IP address.

Next phase:
Phase 8 will connect the Flutter species database and scan record screens to Laravel API data.

## Phase 8A - Species Database API Integration

Implemented:

- Species model API mapping
- Species repository
- Species controller/provider
- Species list API loading
- Species detail API loading
- Search support
- Loading, error, retry, and empty states

Laravel endpoints used:

- GET `/api/species`
- GET `/api/species/{id}`

Next phase:
Phase 8B will connect scan records/history to the Laravel API.

## Phase 8B - Scan Records / History API Integration

Implemented:

- Scan record model API mapping
- Prediction model API mapping
- Measurement model API mapping
- Location validation model API mapping
- Scan record repository
- Records controller/provider
- Records/history API loading
- Record detail page
- Loading, error, retry, and empty states

Laravel endpoints used:

- GET `/api/scan-records`
- GET `/api/scan-records/{id}`

Next phase:
Phase 8C will connect the identification result flow to create scan records using mock AI responses before real camera and AI integration.

## Phase 8C - Mock Identification Flow and Scan Record Creation

Implemented:

- Mock identification result model
- Mock top-k prediction result
- Save Record action
- Scan record creation through Laravel API
- Prediction creation through Laravel API
- Measurement creation through Laravel API
- Location validation creation through Laravel API
- Identification result save state
- Success/error feedback
- Records screen can display saved backend records

Laravel endpoints used:

- POST `/api/scan-records`
- POST `/api/predictions`
- POST `/api/measurements`
- POST `/api/location-validations`
- GET `/api/scan-records`
- GET `/api/scan-records/{id}`

Next phase:
Phase 9 will implement real camera/gallery image selection and prepare image upload.

## Phase 9A - Camera/Gallery Image Selection and Local Preview

Implemented:

- Guided plant-part image selection
- Camera selection using `image_picker`
- Gallery selection using `image_picker`
- Local image preview
- Plant part capture progress
- Remove selected image action
- Identification result image preview

Plant parts supported:

- Leaves
- Bark
- Roots
- Flowers
- Canopy / Full Tree

Not yet implemented:

- Image upload
- Real AI inference
- Real GPS validation
- Offline sync

Next phase:
Phase 9B will implement Laravel image upload preparation and scan image attachment.

## Phase 10 - Camera and Guided Image Capture

Implemented:

- Guided plant-part capture workflow
- Camera image selection
- Gallery image selection
- Capture progress indicator
- Plant part image preview
- Source labels for camera/gallery
- Remove selected image action
- Identification result image preview
- Save Record still supports selected images

Plant parts:

- Leaves
- Bark
- Roots
- Flowers
- Canopy / Full Tree

Not yet implemented:

- GPS validation
- Real AI inference
- Offline sync
- Custom live camera preview

Next phase:
Phase 11 will implement GPS retrieval and location validation.

## Phase 11 - Image Upload and Storage

Implemented:
- Multipart image upload from Flutter
- Plant-part image upload after scan record creation
- Scan image model parsing
- Record detail image display
- Upload success/error feedback

Next phase:
Phase 12 will implement GPS and location validation.

## Phase 12B - Flutter Real GPS Retrieval and Location Validation Integration

Implemented:
- Device GPS retrieval using geolocator
- Location permission handling
- GPS fallback location
- Location controller/provider
- Identification result location display
- Save Record now uses GPS/fallback coordinates
- Laravel validate-location endpoint integration
- Record detail validation display
- Revalidate Location action

Backend endpoint used:
- POST /api/scan-records/{id}/validate-location

Not yet implemented:
- Real map SDK
- Offline GPS queue
- Advanced distribution visualization
- Real AI inference

Next phase:
Phase 13 will implement the mock AI prediction workflow refinement before Python AI service integration.

## Phase 13B - Flutter Mock AI Prediction API Integration

Implemented:
- Mock AI prediction response models
- Mock AI prediction repository
- Laravel /api/ai/mock-predict integration
- Identification result now uses backend mock prediction
- Server top prediction display
- Server top-k predictions display
- Mock explanation display
- Mock measurement estimate display
- Fallback local mock prediction if server prediction fails
- Save Record still uploads images and validates location after saving

Endpoint used:
- POST /api/ai/mock-predict

Not yet implemented:
- Real CNN inference
- YOLOv8 detection
- YOLOv8-Seg segmentation
- MiDaS depth estimation
- Python AI service

Next phase:
Phase 14 will initialize the Python AI service with /health, /predict, and /measure mock endpoints.

## Phase 18A - Measurement Preparation

The measurement screen currently displays prototype/mock height and canopy estimates. Real MiDaS depth estimation will be integrated later.

## Phase 18B - Measurement Result Connected to Flutter Workflow

Implemented:
- AI measurement response model
- AI measurement repository
- Measurement controller/provider
- Flutter Measurement screen connected to Laravel `/api/ai/measure`
- Loading, error, retry, and result states
- Prototype height and canopy width display
- Measurement warning for mock/depth-estimation prototype mode

Endpoint used:
- POST `/api/ai/measure`

Current status:
- Measurement is prototype/mock depth estimation
- Real MiDaS integration is not yet implemented

Next phase:
Phase 19 will integrate the real AI prediction workflow into the mobile save process, or proceed to deployment/testing preparation depending on available YOLO/depth data.

## Phase 19A - End-to-End CNN Prediction Workflow Finalization

Implemented:
- Flutter calls Laravel `/api/ai/predict`
- Multipart image prediction request
- CNN baseline result display
- Mock fallback display if AI service is unavailable
- Save Record uses currently displayed AI result

## Phase 20B - Flutter AI Assistant Integration

Implemented:
- Assistant message model
- Assistant chat response model
- Assistant repository
- Assistant controller/provider
- AI Assistant screen connected to Laravel endpoint
- Chat bubbles
- Quick prompt chips
- Loading and error states
- Optional scan record context support
- Record detail Ask AI Assistant action

Endpoint used:
- POST `/api/ai/assistant/chat`

Current status:
- Rule-based Laravel assistant
- No external LLM API
- Chat history is session-only

Next phase:
Phase 21 will implement offline-online hybrid functionality and sync queue preparation.

## Phase 21A - Offline Queue and Local Sync Preparation

Implemented:
- Offline sync item model
- Offline sync repository
- Offline sync controller/provider
- Connectivity status check
- Offline queue page
- Save Record fallback to local queue when offline
- Profile link to Offline Queue
- Manual sync preparation

Current limitations:
- No background sync yet
- No real offline AI inference yet
- Image upload still requires online connection
- Pending scan sync is prepared for prototype use

Next phase:
Phase 21B will improve sync reliability, add backend conflict handling if needed, and finalize offline-online hybrid behavior.

## Phase 21B - Offline Sync Reliability and Manual Sync Finalization

Implemented:
- Improved offline sync item state
- Retry count and synced timestamp
- Pending/failed/synced queue handling
- Manual Sync Now action
- Retry failed item action
- Clear synced action
- Offline queue status UI
- Safer offline save fallback

Current limitations:
- No background sync yet
- No offline AI inference yet
- Image upload still requires an online retry
- Full conflict resolution is not implemented yet

Next phase:
Phase 22 will finalize reports, analytics, and evaluation outputs for defense preparation.

## Phase 24A-Pre — Pre-Deployment Mobile Polish

Implemented:
- Reusable SILVAMANG AI logo widget
- Logo branding on splash, login, register, home, and profile screens
- Persistent login startup check from splash
- Cached offline session support when `/api/me` is unreachable
- 401/403 auth handling that clears invalid tokens
- Offline session banner on the home dashboard
- Offline Queue quick action on the home dashboard
- Profile Offline Queue menu keeps pending count display

Current behavior:
- Saved token and cached user data are reused while offline.
- Invalid or expired tokens are cleared only when the backend returns 401 or 403.
- Offline Queue still uses manual Refresh Status, Sync Now, and Clear Synced actions.

## Deployment Documentation

Deployment and demo preparation guides are available in:

```text
../docs/deployment/
```

Useful mobile documents:
- Local demo guide
- Flutter APK build guide
- Environment variables guide
- Demo accounts guide
- Pre-defense checklist
