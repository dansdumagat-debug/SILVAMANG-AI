# SILVAMANG AI API

## Current Phase

Laravel backend initialization only.

## Purpose

This Laravel application will serve as the backend API and future admin dashboard foundation for SILVAMANG AI.

## Planned Backend Responsibilities

- User and admin account handling
- Mangrove species management
- Scan record storage
- Captured image storage
- AI prediction result storage
- Height and canopy measurement records
- GPS and location validation records
- AI assistant logs
- Reports and analytics
- AI model health tracking

## Local Setup

composer install
npm install
cp .env.example .env
php artisan key:generate
php artisan install:api
php artisan migrate
php artisan serve

## Health Check

Endpoint:

GET /api/health

Expected response:

{
  "status": "ok",
  "app": "SILVAMANG AI",
  "message": "SILVAMANG AI API is running.",
  "phase": "laravel_initialization"
}

## Next Phase

The next phase will create the database migrations, models, seeders, and API structure for species, scan records, predictions, measurements, and location validation.

## Phase 2B - API Resources, Requests, Controllers, and Routes

Created API layer for:
- species
- scan records
- predictions
- measurements
- location validations
- assistant logs
- AI models
- alerts
- dashboard summary

Main endpoints:
- GET /api/health
- GET /api/species
- POST /api/species
- GET /api/species/{id}
- PUT /api/species/{id}
- DELETE /api/species/{id}
- GET /api/scan-records
- POST /api/scan-records
- GET /api/scan-records/{id}
- GET /api/predictions
- POST /api/predictions
- GET /api/measurements
- POST /api/measurements
- GET /api/location-validations
- POST /api/location-validations
- GET /api/assistant-logs
- POST /api/assistant-logs
- GET /api/ai-models
- GET /api/alerts
- GET /api/admin/dashboard-summary

Next phase:
Phase 3 will implement authentication, roles, protected routes, and user/admin access control.

## Phase 3 - Authentication and Roles

Implemented:
- Laravel Sanctum API token authentication
- Register endpoint
- Login endpoint
- Logout endpoint
- Authenticated user endpoint
- Profile update endpoint
- Password change endpoint
- Roles table
- User-role pivot table
- Role middleware
- Demo users and roles

Auth endpoints:
- POST /api/register
- POST /api/login
- POST /api/logout
- GET /api/me
- PUT /api/profile
- PUT /api/change-password

Demo accounts:
- admin@silvamang.test / password
- researcher@silvamang.test / password
- user@silvamang.test / password

Note:
Demo passwords must be changed before deployment.

Next phase:
Phase 4 will create the Laravel admin dashboard foundation and protected admin layout.

## Phase 4A - Admin Dashboard Foundation

Created:
- Blade admin layout
- Admin sidebar
- Admin topbar
- Dashboard overview page
- Species management page
- Scan records page
- Measurements page
- Location validation page
- AI models page
- AI assistant logs page
- Reports page
- Users page
- Settings page
- Plain CSS admin design system

Next phase:
Phase 4B will improve dashboard interactivity, admin CRUD forms, search, filtering, and data actions.

## Phase 4B-A - Admin Search, Filters, and UI Polish

Implemented:
- Search and filters for admin listing pages
- Pagination styling
- Empty states
- Status badges
- Confidence bars
- Dashboard UI polish
- Responsive table improvements

Next phase:
Phase 4B-B will implement admin CRUD forms for species management and AI model management.

## Phase 4B-B - Admin CRUD Forms for Species and AI Models

Implemented:
- Species create page
- Species detail page
- Species edit page
- Species delete action
- AI model create page
- AI model detail page
- AI model edit page
- AI model delete action
- Flash messages
- Admin form styling
- Validation error display

Next phase:
Phase 4B-C will implement admin CRUD and review pages for scan records, measurements, location validations, assistant logs, and alerts.

## Phase 4B-C - Admin Review Pages

Implemented review pages for:
- Scan records
- Measurements
- Location validations
- AI assistant logs
- Alerts and monitoring

Added:
- Scan record detail page
- Measurement detail page
- Location validation detail page
- Assistant log detail page
- Alerts index page
- Alert detail page
- Alert status update action
- Sidebar alert link
- Detail page styling

Next phase:
Phase 4B-D will implement admin reports and analytics improvements.

## Phase 4B-D - Admin Reports and Analytics Improvements

Implemented:
- Reports filter toolbar
- Scan volume analytics
- Top identified species analytics
- Validation breakdown
- Measurement summary
- AI model performance summary
- Alert summary
- Recent identification records
- Recent alerts
- Dashboard analytics improvements
- CSS-based charts and progress bars

Next phase:
Phase 4B-E will finalize admin user management, settings pages, and admin dashboard cleanup before starting Flutter initialization.

## Phase 4B-E - Admin User Management, Settings Cleanup, and Final Backend UI Review

Implemented:
- Admin user management CRUD
- Role assignment interface
- Admin password reset for users
- User detail page
- Safer user deletion rules
- Read-only settings/system information page
- Backend build status panel
- Sidebar cleanup
- Topbar cleanup
- Final admin CSS cleanup
- Final backend UI review

Backend admin status:
- Laravel backend initialized
- Database schema completed
- API structure completed
- Authentication and roles completed
- Admin dashboard completed
- Admin CRUD/review/report pages completed

Next phase:
Phase 5 will initialize the Flutter mobile app and create the mobile UI design system based on the approved SILVAMANG AI references.

## Phase 9B-A - Scan Image Upload API

Implemented:
- Scan image upload endpoint
- Scan image listing endpoint
- Scan image detail endpoint
- Scan image delete endpoint
- Image metadata storage
- Public storage path support
- Scan image resource output
- Scan record image relationship output

Endpoints:
- GET /api/scan-images
- POST /api/scan-images
- GET /api/scan-images/{id}
- DELETE /api/scan-images/{id}

## Deployment Documentation

Deployment and demo preparation guides are available in:

```text
../docs/deployment/
```

Useful backend documents:
- Laravel backend deployment guide
- Environment variables guide
- Database backup and restore guide
- Demo accounts guide
- Pre-defense checklist

## Phase 16C-B - Export Verified Images to dataset/raw/

Implemented:
- DatasetExportService
- Safe copy of verified uploaded scan images
- Export to dataset/raw/<species>/<plant_part>/
- Manifest CSV update
- Dataset export status tracking
- Admin export action
- Export summary counts
- Artisan export command

Export requirements:
- dataset_status = verified
- verified_species_id is not null
- verified_plant_part is not null
- image_quality = good or acceptable

Important:
Original uploaded scan images are never deleted or moved. Export copies files only.

Next phase:
Phase 16B CNN training can resume after exported images exist in dataset/raw/.

## Phase 18A - AI Measurement Endpoint Preparation

Laravel can call the Python /measure endpoint and fallback to Laravel mock measurement if Python is unavailable.

## Phase 19A - End-to-End CNN Prediction Workflow Finalization

Implemented:
- Clean `/api/ai/predict` route
- Existing `/api/ai/mock-predict` kept for compatibility
- Laravel forwards image prediction to Python CNN service
- Laravel fallback mock prediction preserved
- Response normalized for Flutter

## Phase 20A - Laravel AI Assistant Backend and Logs

Implemented:
- Rule-based mangrove assistant service
- Assistant chat endpoint
- Species-aware answers
- Scan-record-aware answers
- Intent detection
- Assistant log storage
- Admin assistant log visibility

Endpoint:
- POST `/api/ai/assistant/chat`

Current status:
- Rule-based prototype assistant
- No external LLM API
- No paid AI service
- Future enhancement may connect to a larger NLP/LLM model

Next phase:
Phase 20B will connect the Flutter AI Assistant screen to this Laravel assistant endpoint.

## Phase 22A - Reports, Analytics, and Evaluation Evidence Finalization

Implemented:
- System overview report
- Identification analytics
- Location validation analytics
- Measurement summary
- CNN baseline metrics reader
- CNN evaluation section
- Confusion matrix preview/link
- Print-friendly admin report page

Important:
Reports only display actual data. Missing evaluation files are shown as unavailable, not fabricated.

Next phase:
Phase 23 will prepare formal testing, evaluation tables, and defense evidence.

## Phase 16C-A - Dataset Collection and Verification Workflow

Implemented:
- Dataset verification fields for uploaded scan images
- Admin dataset verification page
- Dataset image review page
- Species verification dropdown
- Plant-part verification dropdown
- Image quality status
- Dataset status tracking
- Scan record detail verification metadata
- Dataset verification sidebar link

Purpose:
This workflow allows researchers/admins to verify uploaded scan images before using them for future CNN and YOLOv8 training.

Dataset statuses:
- pending
- verified
- rejected
- exported

Next phase:
Phase 16C-B will implement safe export of verified images into dataset/raw/.

## Phase 13A - Laravel Mock AI Prediction API

Implemented:
- Mock AI prediction endpoint
- Top prediction response
- Top-k prediction response
- Mock model metadata
- Mock species explanation
- Mock measurement estimate
- Optional image/plant-part input handling

Endpoint:
- POST /api/ai/mock-predict

This endpoint does not perform real AI inference yet.
Real CNN, YOLOv8, segmentation, and depth estimation will be added in later phases.

Next phase:
Phase 13B will connect Flutter identification result flow to the Laravel mock AI prediction endpoint.

## Phase 14B - Laravel Connects to Python AI Service

Implemented:
- Python AI service configuration
- PythonAiService client
- AI service health endpoint
- Laravel to Python /predict proxy
- Laravel to Python /measure proxy
- Laravel fallback mock prediction
- Laravel fallback mock measurement

Configuration:
AI_SERVICE_URL=http://127.0.0.1:9000
AI_SERVICE_TIMEOUT=30
AI_SERVICE_MODE=mock

Endpoints:
- GET /api/ai/service-health
- POST /api/ai/mock-predict
- POST /api/ai/measure

Important:
The Python AI service must be running manually for Laravel to receive Python mock responses:
uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload

If Python service is unavailable, Laravel returns fallback mock responses.

Next phase:
Phase 15 will prepare dataset collection and organization for CNN and YOLOv8 training.

## Phase 12A - Laravel GPS and Location Validation Engine

Implemented:
- LocationValidationService
- Haversine distance calculation
- Species distribution comparison
- Location validation result logic
- Dedicated scan record location validation endpoint
- Automatic validation record update
- Scan record validation status update
- Admin validation display improvements

Validation results:
- match
- mismatch
- likely_found
- unknown

Endpoint:
- POST /api/scan-records/{id}/validate-location
- POST /api/location-validations

Next phase:
Phase 12B will connect Flutter real GPS retrieval and call the Laravel location validation endpoint.

Supported plant parts:
- leaves
- bark
- roots
- flowers
- canopy
- full_tree
- other

Next phase:
Phase 9B-B will connect Flutter selected images to the Laravel scan image upload API.

## Phase 11 - Image Upload and Storage

Implemented:
- Scan image upload API
- Scan image storage in Laravel public disk
- Scan image metadata database records
- Scan image resource output
- Scan record image relationship
- Admin scan record image display

Endpoints:
- GET /api/scan-images
- POST /api/scan-images
- GET /api/scan-images/{id}
- DELETE /api/scan-images/{id}
