# SILVAMANG AI Demo Script

## 1. Opening Introduction

Good day. This is SILVAMANG AI, a mobile-based mangrove species identification system using image recognition. The system supports field data collection, AI-assisted species prediction, GPS validation, measurement display, record storage, and admin monitoring.

## 2. System Overview

The system has three main parts:

- Laravel backend API and admin dashboard
- Flutter mobile app for field users
- Python FastAPI AI service for CNN baseline prediction

## 3. Laravel Admin Dashboard Demo

Show:

- Admin login
- Dashboard overview
- Species management
- Scan records review
- Dataset verification
- Reports and analytics
- Assistant logs and alerts if available

## 4. Flutter Mobile App Demo

Show:

- Splash screen
- Login
- Home dashboard
- Navigation shell
- Species database
- Records screen
- Profile screen

## 5. Image Capture Demo

Open the capture guide and explain the guided plant-part flow. Select or capture a mangrove image for prediction.

## 6. CNN Prediction Demo

Run prediction and explain that the CNN baseline is working. Show the top prediction and top-k prediction results.

## 7. Save Scan Record Demo

Save the prediction result as a scan record. Show that the saved record appears in the records screen and can be reviewed later.

## 8. GPS Validation Demo

Show the captured coordinates or fallback location and explain location validation. Display the validation result from the backend.

## 9. Measurement Demo

Open the measurement screen and explain that measurement is prototype/mock depth-estimation unless real MiDaS is integrated.

## 10. AI Assistant Demo

Open AI Assistant and ask a mangrove-related question. Show the response and explain that it supports users during field work.

## 11. Offline Queue Demo

Show Offline Queue and explain that offline records can be queued and manually synced when the backend becomes reachable again.

## 12. Reports and Analytics Demo

Open the admin reports page and show scan summary, species statistics, validation data, and CNN evaluation evidence where available.

## 13. Known Limitations

Be clear that:

- CNN baseline is working.
- YOLOv8 is pending annotation/training.
- Measurement is prototype/mock depth-estimation unless real MiDaS is integrated.
- Dataset expansion can continue after deployment.

## 14. Closing Statement

This deployed demo demonstrates the full SILVAMANG AI workflow from image capture to species prediction, record storage, GPS validation, measurement display, AI assistant support, and admin monitoring.
