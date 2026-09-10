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

if [ "${DB_CONNECTION:-sqlite}" = "sqlite" ]; then
    DB_FILE="${DB_DATABASE:-/var/www/html/database/database.sqlite}"
    mkdir -p "$(dirname "$DB_FILE")"
    touch "$DB_FILE"
fi

php artisan migrate --force
php artisan db:seed --force

php artisan config:clear
php artisan storage:link || true
php artisan config:cache
php artisan route:cache || true
php artisan view:cache

php artisan serve --host=0.0.0.0 --port="${PORT:-10000}"
