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
| `DB_CONNECTION` | Database driver; Render Docker defaults to `sqlite`, so set `pgsql` explicitly when using Render Postgres |
| `DATABASE_URL` | Render Postgres connection URL when `DB_CONNECTION=pgsql` |
| `DB_HOST` | Database host |
| `DB_PORT` | Database port |
| `DB_DATABASE` | Database name, or absolute persistent SQLite file path |
| `DB_USERNAME` | Database username |
| `DB_PASSWORD` | Database password |
| `FILESYSTEM_DISK` | Default Laravel disk; scan photos use the `public` disk explicitly |
| `PUBLIC_STORAGE_ROOT` | Absolute path for the `public` disk and its web link; put it under a persistent disk mount on Render |
| `DATASET_EXPORT_ROOT` | Absolute path for verified dataset exports; put it under a persistent disk mount on Render |
| `SEED_ON_START` | Set `false` after initial setup to avoid changing existing field data |
| `AI_SERVICE_URL` | Python AI service URL |
| `AI_SERVICE_TIMEOUT` | Laravel to AI service timeout |
| `AI_SERVICE_MODE` | AI mode, such as `mock` or `cnn` |
| `AI_CONFIDENCE_THRESHOLD` | Minimum accepted species probability from `0` to `1`; defaults to `0.70` |
| `AI_PROVIDER` | Chatbot provider; set `openai` for the OpenAI API |
| `OPENAI_API_KEY` | Secret server-side OpenAI project key; never place it in Flutter or source control |
| `OPENAI_MODEL` | OpenAI chatbot model, currently `gpt-4o` by default |
| `OPENAI_BASE_URL` | OpenAI API root, normally `https://api.openai.com/v1` |
| `OPENAI_ORGANIZATION` | Optional OpenAI organization ID |
| `OPENAI_PROJECT` | Optional OpenAI project ID |
| `AI_CHATBOT_TIMEOUT` | Chatbot provider timeout in seconds |
| `AI_CHATBOT_MAX_OUTPUT_TOKENS` | Maximum tokens generated for one chatbot response; defaults to `600` |
| `AI_CHATBOT_INCLUDE_PRECISE_LOCATION` | Allow exact GPS and manual location notes in external AI context; defaults to `false` |

## Flutter

| Variable | Purpose |
| --- | --- |
| `API_BASE_URL` | Laravel API base URL |
| `APP_NAME` | Mobile app name |
| `APP_TAGLINE` | Mobile app tagline |
| `AI_CONFIDENCE_THRESHOLD` | Offline classifier acceptance threshold from `0` to `1`; keep it aligned with Laravel |

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
| `CNN_MODEL_PATH` | Optional absolute or service-relative path to the active EfficientNet checkpoint |
| `CNN_CLASS_ORDER_PATH` | Optional absolute or service-relative path to its exact matching `class_order.json` |

## Warning

Never commit real `.env` files. Keep secrets out of GitHub, screenshots, and shared documents.
