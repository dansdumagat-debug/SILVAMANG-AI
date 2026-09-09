# SILVAMANG AI API Endpoints

Base URL: `http://127.0.0.1:8000/api`

## Auth
- `POST /login` - login user. Auth required: no.
- `POST /register` - register user. Auth required: no.
- `GET /me` - current user. Auth required: yes.
- `POST /logout` - logout user. Auth required: yes.

## Species
- `GET /species` - list species. Auth required: no.
- `GET /species/{id}` - show species. Auth required: no.

## Scan Records
- `GET /scan-records` - list records. Auth required: yes.
- `POST /scan-records` - create record. Auth required: yes.
- `GET /scan-records/{id}` - show record. Auth required: yes.

## Scan Images
- `POST /scan-images` - upload scan image. Auth required: yes. Multipart request with scan record id, plant part, and image file.

## Predictions
- `POST /predictions` - store prediction. Auth required: no/current API dependent.

## Measurements
- `POST /measurements` - store measurement. Auth required: no/current API dependent.
- `POST /ai/measure` - get AI measurement estimate. Auth required: yes.

## Location Validation
- `POST /scan-records/{id}/validate-location` - validate scan record location. Auth required: yes.

## AI Prediction
- `POST /ai/predict` - run Python/CNN prediction via Laravel. Auth required: yes.
- `POST /ai/mock-predict` - compatibility prediction endpoint. Auth required: yes.
- `GET /ai/service-health` - check Python AI service health. Auth required: yes.

## AI Assistant
- `POST /ai/assistant/chat` - rule-based assistant chat. Auth required: yes.

Sample request:

```json
{
  "question": "What is the ecological role of Rhizophora apiculata?",
  "scan_record_id": 1
}
```

## Admin Summary
- `GET /admin/dashboard-summary` - admin dashboard summary. Auth required: yes.
