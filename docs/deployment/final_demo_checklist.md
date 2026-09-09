# Final Demo Checklist

## Before Demo

- [ ] Start Laragon/MySQL
- [ ] Start Python AI service
- [ ] Start Laravel backend
- [ ] Open Flutter app or install debug APK
- [ ] Confirm API base URL
- [ ] Confirm demo accounts
- [ ] Prepare test mangrove image
- [ ] Prepare admin login
- [ ] Prepare mobile login

## Demo Flow

1. Show splash/login.
2. Login as mobile user.
3. Show home dashboard.
4. Open species database.
5. Open capture guide.
6. Select/capture mangrove image.
7. Run CNN prediction.
8. Show identification result.
9. Save scan record.
10. Show measurement result.
11. Show GPS validation.
12. Show records/history.
13. Ask AI assistant.
14. Show offline queue.
15. Login to admin dashboard.
16. Show scan records.
17. Show uploaded images.
18. Show reports and analytics.
19. Show CNN metrics/confusion matrix if available.
20. Explain known limitations.

## Known Limitation Statement

Use this wording:

"The current deployed demo includes a trained CNN baseline for species classification. YOLOv8 detection is pending because bounding-box annotations are not yet available. Measurement output is currently prototype/mock depth estimation until full MiDaS integration is completed."
