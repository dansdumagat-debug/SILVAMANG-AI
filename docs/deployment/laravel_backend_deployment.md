# Laravel Backend Deployment Guide

## 1. Current Local Setup

Backend folder:

```text
silvamang_api/
```

Local API:

```text
http://127.0.0.1:8000/api
```

Local admin dashboard:

```text
http://127.0.0.1:8000/admin
```

## 2. Production Requirements

- PHP version compatible with the Laravel project
- Composer
- MySQL or compatible database
- Web server configured for Laravel `public/`
- Writable `storage/` and `bootstrap/cache/`
- HTTPS for real deployment

## 3. Environment Variables

Production examples:

```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.example
```

Never commit real `.env` files.

## 4. Database Setup

Create a production database and user with a strong password. Configure:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=silvamang_ai
DB_USERNAME=your_database_user
DB_PASSWORD=your_strong_password
```

## 5. File Storage Setup

Uploaded scan images are stored through Laravel storage. Confirm the configured disk and storage permissions.

Recommended setting:

```env
FILESYSTEM_DISK=public
```

## 6. Public Storage Link

```powershell
php artisan storage:link
```

## 7. Admin Dashboard Access

Admin routes are protected by authentication and role middleware. Change all demo passwords before any public deployment.

## 8. Security Checklist

- Do not upload `.env` to GitHub.
- Change demo passwords.
- Use a strong database password.
- Set `APP_DEBUG=false`.
- Verify storage permissions.
- Restrict admin access.
- Use HTTPS.
- Review CORS and allowed origins.

## 9. Deployment Commands

```powershell
composer install --optimize-autoloader --no-dev
php artisan key:generate
php artisan migrate --force
php artisan storage:link
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

## 10. Post-Deployment Checks

```powershell
php artisan route:list
curl.exe https://your-domain.example/api/health
```

Also verify:

- Admin login works.
- Image upload works.
- Python AI service URL is reachable from Laravel.
- Public storage images are readable.
