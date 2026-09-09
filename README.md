# SILVAMANG AI

Mobile-Based Mangrove Species Identification System Using Image Recognition

## Current Build Order

1. Laravel backend initialization
2. Laravel database and API structure
3. Laravel admin dashboard foundation
4. Flutter mobile app initialization
5. Flutter mobile UI implementation
6. AI service integration
7. Testing and deployment

## Current Phase

Laravel backend initialization only.

## Main Folders

silvamang_api/ - Laravel backend API and future admin dashboard  
silvamang_ai_service/ - Python FastAPI mock AI service  
docs/ - project documents, diagrams, and notes  
dataset/ - future mangrove image dataset and annotations  

## Phase Status

Phase 14A Python AI Service Initialization - Completed

## Phase 15A - Dataset Folder Structure, Labels, and Metadata Templates

Created:
- Dataset folder structure
- Species labels
- Plant-part labels
- YOLO class labels
- Metadata CSV templates
- YOLO data.yaml

Next phase:
Phase 15B will create dataset collection guides, annotation workflow documentation, evaluation plan, and helper scripts.

## Phase 15B - Dataset Guides, Annotation Workflow, Evaluation Plan, and Helper Scripts

Created:
- Dataset collection guide
- Image quality checklist
- Annotation workflow
- Evaluation plan
- Lightweight dataset helper scripts

Next phase:
Phase 16 will prepare the CNN species classification baseline.

## Phase 16A - CNN Species Classification Baseline Pipeline

Created:
- Baseline CNN pipeline
- Dataset split preparation
- Training script
- Evaluation script
- Prediction script
- Model output folder
- Metrics output folder

Next phase:
Phase 16B will run the baseline CNN training after enough verified dataset images are available.

## Phase 16C-B - Export Verified Images to dataset/raw/

Created:
- Safe verified image export workflow
- Dataset export service
- Admin export action and summary counts
- Manifest CSV append support
- Artisan export command

Important:
Original uploaded scan images are copied only, never deleted or moved.

Next phase:
Phase 16B CNN training can resume after exported images exist in dataset/raw/.

## Phase 16C - CNN Baseline Connected to Python AI Service

Completed:
- Trained CNN baseline model connected to FastAPI AI service
- /predict can now return CNN baseline species predictions
- mock fallback preserved
- /health reports CNN model availability

Next phase:
Phase 17 - YOLOv8 Detection and Segmentation Preparation

## Phase 17A - YOLOv8 Detection and Segmentation Preparation

Completed:
- YOLOv8 detection pipeline structure
- YOLOv8-Seg segmentation pipeline structure
- Plant-part labels
- Validation scripts
- Training script placeholders
- Documentation

Next phase:
Phase 17B - YOLOv8 Detection Training
# SILVAMANG AI

## Phase 23 - Testing and Evaluation Evidence Preparation

Created:
- Test plan
- Functional test cases
- API test cases
- Mobile test cases
- Admin test cases
- AI evaluation summary template
- Usability evaluation form
- Measurement evaluation template
- Location validation evaluation template
- Requirements traceability matrix
- Defect log template
- Defense evidence checklist
- API endpoint documentation
- Postman collection
- Evidence folders
- Helper scripts

Next phase:
Phase 24 will prepare deployment and demo build.

## Phase 24A - Deployment and Demo Build Preparation

Created:
- Local demo guide
- Laravel backend deployment guide
- Flutter APK build guide
- Python AI service deployment guide
- Database backup and restore guide
- Environment variables documentation
- Demo accounts documentation
- Pre-defense checklist
- Known limitations document
- Verification scripts

Current status:
- Ready for local demo and capstone defense testing
- Production deployment still requires hosting configuration and security hardening

Deployment docs:
- docs/deployment/

Next phase:
Phase 24B will prepare actual demo builds and local deployment verification.

## Phase 24B - Demo Build and Local Deployment Verification

Prepared:
- Local demo verification documents
- Demo script
- APK build verification guide
- Troubleshooting guide
- Demo status report template
- Verification scripts

Next phase:
Phase 24C - Actual Demo Verification and APK Build

## Phase 24C - Actual Demo Verification and APK Build

Prepared:
- Demo verification results document
- APK build results document
- Final demo checklist
- Static check script
- Debug APK build script

Next phase:
Phase 25 - Documentation and Final Defense Preparation
