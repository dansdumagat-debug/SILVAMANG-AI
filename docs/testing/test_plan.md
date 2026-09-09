# SILVAMANG AI Test Plan

## 1. Purpose
Define the testing strategy and evidence requirements for SILVAMANG AI.

## 2. Scope of Testing
Testing covers the Laravel backend, Flutter mobile app, Python AI service, CNN baseline evidence, admin dashboard, image upload, GPS validation, measurement, AI assistant, and offline queue.

## 3. System Modules Covered
Authentication, species database, guided capture, scan records, image upload, prediction, measurement, location validation, assistant logs, reports, admin review pages, and offline sync queue.

## 4. Testing Types
Functional, API, mobile UI, admin dashboard, integration, AI evaluation review, usability, and requirements traceability testing.

## 5. Test Environment
Local development environment using Laravel, Flutter, FastAPI, MySQL, and available test devices or browser targets.

## 6. Test Data
Use actual seeded data, uploaded scan images, verified dataset images, and generated CNN evaluation files. Do not fabricate results.

## 7. Entry Criteria
Application modules are implemented, dependencies installed, database migrated, and required services available for the test being executed.

## 8. Exit Criteria
Required test cases are executed, defects are logged, evidence screenshots are saved, and summaries are completed.

## 9. Functional Testing
Validate user workflows including authentication, capture, prediction, record saving, image upload, GPS validation, assistant chat, offline queue, and admin review.

## 10. API Testing
Validate backend endpoints using the provided API test cases and Postman collection.

## 11. Mobile Testing
Validate screen rendering, navigation, form behavior, capture flow, and offline queue interactions.

## 12. Admin Dashboard Testing
Validate dashboard statistics, CRUD/review pages, dataset verification, reports, and user management.

## 13. AI Model Testing
CNN metrics must come from actual generated evaluation files. YOLO metrics are pending until bounding-box annotations are available.

## 14. GPS/Location Validation Testing
Compare expected species distribution results against system output using the location validation template.

## 15. Measurement Testing
Measurement is prototype/mock unless real depth estimation is integrated. Use the measurement evaluation template for comparison when reference measurements are available.

## 16. Offline Queue Testing
Verify offline save fallback, queue visibility, retry behavior, failed item preservation, and manual sync.

## 17. Usability Testing
Collect participant responses using the usability evaluation form. Do not add fake participants or fabricated survey scores.

## 18. Defect Logging
Record defects in `defect_log_template.csv` with reproducible steps and status.

## 19. Evidence Requirements
Screenshots, route/API outputs, CNN files, test summaries, usability forms, and dataset evidence should be saved under `docs/testing/evidence/`.

## 20. Limitations
YOLO training is blocked until annotations are available. Measurement remains prototype/mock until MiDaS or another real depth-estimation method is integrated. AI assistant is rule-based until external NLP/LLM integration is added.
