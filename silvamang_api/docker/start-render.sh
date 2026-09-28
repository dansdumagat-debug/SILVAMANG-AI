#!/usr/bin/env sh
set -eu

cd /var/www/html

normalize_url_env() {
    name="$1"
    fallback="$2"
    value="$(printenv "$name" 2>/dev/null || true)"

    value="$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

    if printf '%s' "$value" | grep -Eq '^\[https?://[^]]+\]\(https?://[^)]+\)'; then
        value="$(printf '%s' "$value" | sed -E 's/^\[https?:\/\/[^]]+\]\((https?:\/\/[^)]+)\).*$/\1/')"
    fi

    case "$value" in
        http://*|https://*) ;;
        *) value="$fallback" ;;
    esac

    export "$name=$value"
}

normalize_url_env APP_URL "https://${RENDER_EXTERNAL_HOSTNAME:-silvamang-api-service.onrender.com}"
normalize_url_env AI_SERVICE_URL "https://silvamang-ai-service.onrender.com"

if [ -z "${APP_KEY:-}" ]; then
    echo "APP_KEY is missing. Add it in Render Environment Variables."
    exit 1
fi

echo "Render startup APP_URL=$APP_URL"
echo "Render startup AI_SERVICE_URL=$AI_SERVICE_URL"

mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache database
chmod -R 775 storage bootstrap/cache database || true

# Scan uploads and training exports must live under the Render disk mount when
# local files need to survive deployments.
if [ -n "${PUBLIC_STORAGE_ROOT:-}" ]; then
    mkdir -p "$PUBLIC_STORAGE_ROOT"
    if [ ! -w "$PUBLIC_STORAGE_ROOT" ]; then
        echo "PUBLIC_STORAGE_ROOT is not writable: $PUBLIC_STORAGE_ROOT"
        exit 1
    fi
fi

if [ -n "${DATASET_EXPORT_ROOT:-}" ]; then
    mkdir -p "$DATASET_EXPORT_ROOT"
    if [ ! -w "$DATASET_EXPORT_ROOT" ]; then
        echo "DATASET_EXPORT_ROOT is not writable: $DATASET_EXPORT_ROOT"
        exit 1
    fi
fi

if [ "${DB_CONNECTION:-sqlite}" = "sqlite" ]; then
    DB_FILE="${DB_DATABASE:-/var/www/html/database/database.sqlite}"
    mkdir -p "$(dirname "$DB_FILE")"
    touch "$DB_FILE"
    chmod 664 "$DB_FILE" || true
    if [ ! -w "$DB_FILE" ]; then
        echo "SQLite database is not writable: $DB_FILE"
        exit 1
    fi
fi

php artisan migrate --force

# Seed only when explicitly bootstrapping an empty database. Re-seeding on
# every deploy can overwrite field data and reset demo account passwords.
if [ "${SEED_ON_START:-false}" = "true" ]; then
    php artisan db:seed --force
fi

php artisan config:clear
php artisan storage:link || true
php artisan config:cache
php artisan route:cache || true
php artisan view:cache

php artisan serve --host=0.0.0.0 --port="${PORT:-10000}"
