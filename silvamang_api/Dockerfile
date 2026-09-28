FROM node:22-bookworm-slim AS assets
WORKDIR /build
COPY package.json package-lock.json ./
RUN npm ci
COPY vite.config.js ./
COPY resources ./resources
RUN npm run build

FROM php:8.2-apache-bookworm AS php-base
RUN apt-get update && apt-get install -y --no-install-recommends \
    libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev libonig-dev libxml2-dev unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) bcmath gd mbstring pdo_mysql zip opcache \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /var/www/html

FROM php-base AS dependencies
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-autoloader
COPY . .
RUN composer dump-autoload --no-dev --classmap-authoritative --no-scripts \
    && composer check-platform-reqs --no-dev

FROM php-base AS production
ENV APP_ENV=production APP_DEBUG=false LOG_CHANNEL=stderr
COPY --from=dependencies /var/www/html /var/www/html
COPY --from=assets /build/public/build ./public/build
COPY docker/apache.conf /etc/apache2/sites-available/000-default.conf
COPY docker/production.ini /usr/local/etc/php/conf.d/production.ini
RUN printf 'Listen 8080\n' > /etc/apache2/ports.conf \
    && mkdir -p storage/app/public storage/app/dataset storage/app/model-reports \
       storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
       /var/run/apache2 /var/lock/apache2 \
    && chown -R www-data:www-data storage bootstrap/cache /var/run/apache2 /var/lock/apache2 \
    && ln -s /var/www/html/storage/app/public public/storage \
    && chmod +x docker/start-production.sh
USER www-data
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD php -r 'exit(@file_get_contents("http://127.0.0.1:8080/api/health") === false ? 1 : 0);'
ENTRYPOINT ["sh", "docker/start-production.sh"]
CMD ["apache2-foreground"]
