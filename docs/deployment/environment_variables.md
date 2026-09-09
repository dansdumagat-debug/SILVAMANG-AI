# Environment Variables Guide

Never commit real `.env` files.

## Laravel

| Variable | Purpose |
| --- | --- |
| `APP_NAME` | Application name |
| `APP_ENV` | Local, staging, or production environment |
| `APP_KEY` | Laravel encryption key |
| `APP_DEBUG` | Debug mode; use `false` in production |
| `APP_URL` | Backend URL |
| `DB_CONNECTION` | Database driver, usually `mysql` |
| `DB_HOST` | Database host |
| `DB_PORT` | Database port |
| `DB_DATABASE` | Database name |
| `DB_USERNAME` | Database username |
| `DB_PASSWORD` | Database password |
| `FILESYSTEM_DISK` | Storage disk for uploads |
| `AI_SERVICE_URL` | Python AI service URL |
| `AI_SERVICE_TIMEOUT` | Laravel to AI service timeout |
| `AI_SERVICE_MODE` | AI mode, such as `mock` or `cnn` |

## Flutter

| Variable | Purpose |
| --- | --- |
| `API_BASE_URL` | Laravel API base URL |
| `APP_NAME` | Mobile app name |
| `APP_TAGLINE` | Mobile app tagline |

## Python

| Variable | Purpose |
| --- | --- |
| `APP_NAME` | Service name |
| `APP_ENV` | Local, staging, or production environment |
| `APP_DEBUG` | Debug mode |
| `SERVICE_HOST` | Service bind host |
| `SERVICE_PORT` | Service port |
| `MODEL_MODE` | Model mode |
| `MOCK_MODEL_VERSION` | Mock model version label |

## Warning

Never commit real `.env` files. Keep secrets out of GitHub, screenshots, and shared documents.
