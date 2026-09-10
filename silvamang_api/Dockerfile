FROM php:8.2-cli

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        sqlite3 \
        libsqlite3-dev \
        libpq-dev \
        libzip-dev \
        libpng-dev \
        libonig-dev \
    && docker-php-ext-install \
        bcmath \
        gd \
        mbstring \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

ENV APP_NAME="SILVAMANG AI" \
    APP_ENV=production \
    APP_DEBUG=false \
    APP_URL=https://silvamang-api-service.onrender.com \
    DB_CONNECTION=sqlite \
    DB_DATABASE=/var/www/html/database/database.sqlite \
    LOG_CHANNEL=stderr \
    CACHE_DRIVER=file \
    SESSION_DRIVER=file \
    QUEUE_CONNECTION=sync \
    AI_SERVICE_URL=https://silvamang-ai-service.onrender.com \
    AI_SERVICE_TIMEOUT=60 \
    AI_SERVICE_MODE=live

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

COPY . .

RUN composer dump-autoload --optimize \
    && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache database \
    && touch database/database.sqlite \
    && chmod -R 775 storage bootstrap/cache database \
    && chmod +x docker/start-render.sh

CMD ["sh", "docker/start-render.sh"]
