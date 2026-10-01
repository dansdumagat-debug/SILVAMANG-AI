#!/bin/sh
set -eu
cd /var/www/html
: "${APP_KEY:?Set a permanent APP_KEY in Dokploy}"
if [ "${APP_ENV:-}" != production ] || [ "${APP_DEBUG:-false}" != false ]; then
    echo 'Production requires APP_ENV=production and APP_DEBUG=false' >&2
    exit 1
fi
mkdir -p storage/app/public storage/app/dataset storage/app/model-reports \
    storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    storage/framework/cli/config storage/framework/cli/data
chmod 700 storage/framework/cli
for directory in storage bootstrap/cache; do
    test -w "$directory" || { echo "$directory must be writable by uid 33" >&2; exit 1; }
done
php artisan config:clear
php artisan package:discover --ansi
php artisan config:cache
php artisan route:cache
php artisan view:cache
# No migrations, seeding, key generation, or data resets at startup.
exec "$@"
