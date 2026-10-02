# Production deployment: silvamangai.online

## A. Architecture audit

- Laravel **10.50.2** (Composer lock), PHP 8.1+; production image uses PHP 8.2 with Apache on **8080**. Website and admin pages use Blade and static public assets. Vite 5 builds CSS/JS in a separate Node 22 stage; Node is absent from the runtime image.
- MySQL is configured in the existing local API environment. The old Render image defaulted to SQLite; this Compose stack uses **MySQL 8.4**. An existing SQLite installation needs an explicit, verified data conversion before cutover; mounting a SQLite file will not import it into MySQL.
- FastAPI, Uvicorn, PyTorch, torchvision, Ultralytics run as a private Python 3.12 service on **9000**, with one CPU inference worker to avoid duplicating model memory. Runtime dependency versions match the inspected local environment. Model compatibility and Linux wheel availability must be verified by the image build and readiness gate.
- Flutter/Dart 3.12 is a separately built mobile client, not a website container. Its public API URL is `https://silvamangai.online/api`. No mobile signing secrets belong in Compose or the repository.
- Laravel uses file sessions/cache and synchronous jobs. There are no active scheduled tasks or dispatched queue jobs requiring a worker, scheduler or Redis service.
- Laravel uploads, dataset exports and CNN report files use the persistent storage volume. Metrics/report paths are configurable so existing admin reporting continues to work without a sibling source checkout.

## B/C. Files prepared

Created: root `docker-compose.yml`, `.env.example`, `.gitattributes`; API `docker/apache.conf`, `docker/production.ini`, `docker/start-production.sh`, `config/deployment.php`, `tests/Feature/ProductionDeploymentTest.php`; AI `Dockerfile`, `.dockerignore`, `requirements-production.txt`, `docker/check-models.py`; this guide.

Modified: root `.gitignore`; API `Dockerfile`, `.dockerignore`, `.env.example`, `config/cors.php`, `app/Http/Middleware/TrustProxies.php`, `app/Services/CnnMetricsReaderService.php`, `app/Http/Controllers/Admin/ReportController.php`; AI `app/main.py`, `.env.example`; mobile `.env.example`, `lib/core/config/api_config.dart`, `test/api_config_test.dart`; deployment README.

The existing Render startup script is retained for historical deployments but is not invoked by this Dockerfile. Local secret environments and pre-existing work are preserved.

## D/E/F. Services, ports and persistence

| Service | Internal port | Persistence | Public routing |
| --- | --- | --- | --- |
| app | 8080 HTTP | `app_storage` at `/var/www/html/storage` | Both production domains |
| database | 3306 | `database_data` at `/var/lib/mysql` | None |
| ai | 9000 HTTP | `ai_cache` at `/home/ai/.cache`; read-only host model directory at `/app/models` | None |

There are no host port bindings. Only `app` joins `dokploy-network`; all three services share the project backend network. Traefik terminates TLS. Do not add database/AI domains or published ports.

Named volumes are scoped to the Compose project. Keep the same Dokploy Compose application/project identity on redeploys. Changing its identity can select new empty volumes; it does not migrate existing data. Never use `down -v`, volume prune, or delete volumes for a normal release. Run one app replica with these local volumes.

## G. Dokploy environment

Copy the **root** `.env.example` into the Compose Environment tab. Service `.env` files are neither copied into images nor read by Compose.

Required values:

| Variable | Value/action |
| --- | --- |
| `APP_KEY` | Existing installation: preserve its key. New installation: generate once and store securely. |
| `DB_DATABASE` | `silvamang_ai` |
| `DB_USERNAME` | `silvamang` (application user, never `root`) |
| `DB_PASSWORD` | Unique strong application database password |
| `DB_ROOT_PASSWORD` | Different strong database administrator password |
| `AI_MODELS_DIR` | Absolute server directory, e.g. `/opt/silvamang/models` |
| `OPENAI_API_KEY` | Required for the configured OpenAI chatbot provider; leave empty only if knowingly using local fallback or another provider |

Keep `TRUSTED_PROXIES=*` only with the supplied network-only app access. You may restrict it to the actual proxy IP/CIDR. Proxy headers are trusted by Laravel; secure cookies and canonical storage URLs use HTTPS. Never route arbitrary public clients directly to Apache. CORS permits both production origins; native Flutter requests are unaffected by browser CORS.

Compose fixes `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL=https://silvamangai.online`, `DB_HOST=database`, `AI_SERVICE_URL=http://ai:9000`, file cache/sessions and secure cookies. Those values do not need to be pasted into Dokploy. Optional provider/SMTP settings are listed in the root template. The old sample provider/model names are retained; choose a model available to your account.

For a **new** installation only, generate a key on a trusted computer with PHP:

```sh
php -r 'echo "base64:".base64_encode(random_bytes(32)).PHP_EOL;'
```

Do not regenerate this key on redeploy. Database initialization variables only create credentials on an empty MySQL volume. Changing a password in Dokploy does not rotate an existing MySQL user's password; coordinate the database change separately.

## H. Dokploy configuration

1. Create a **Docker Compose** application using the GitHub repository and intended branch. Select `docker-compose.yml` at repository root. Use Compose, not Docker Stack/Swarm mode.
2. Use repository root as the working/build directory. The two service Dockerfiles are selected by Compose.
3. Keep **Isolated Deployments disabled** for this configuration, which explicitly uses the existing external `dokploy-network`. Do not install Traefik in this repository.
4. Paste environment values above. In Domains add:

| Host | Service | Container port | Path | HTTPS |
| --- | --- | --- | --- | --- |
| `silvamangai.online` | `app` | `8080` | `/` | Enabled, Let's Encrypt |
| `www.silvamangai.online` | `app` | `8080` | `/` | Enabled, Let's Encrypt |

Enable HTTP-to-HTTPS redirection. Both names serve the application; generated storage links use the canonical apex URL. The apex is the mobile API origin. No path stripping is required.

Use Dokploy's **Preview Compose** to confirm app retains both networks and database/AI remain on backend only. Dokploy supplies routing labels through its Domains UI: [official Compose domain documentation](https://docs.dokploy.com/docs/core/docker-compose/domains).

## I/J. Release commands and manual preparation

Do these only when ready to deploy. No deployment was performed as part of preparation.

1. Back up the current database, uploads, model files, exports, evaluation reports and original application key. Test a restore in an isolated environment. If moving an existing installation, import its database and copy files before directing users to the new instance. Preserve upload-relative paths.
2. Copy the trusted model bundle to `AI_MODELS_DIR` on the **deployment host**, preserving case and spaces:

```text
EfficientNet-B0/efficientnet_b0_runtime.pth
EfficientNet-B0/class_order.json
YOLOv8-Detector/yolo8 detection.pt
YOLOv8-Seg/yolo8 seg.pt
```

The directory must already exist and be readable/traversable by container UID 10001. Compare SHA-256 checksums against your source bundle. Store model backups separately; these files do not need to be in Git. MiDaS is retired and is not required for readiness. Calibrated reference measurements do not load a depth model. Warm and validate models before admitting users. Only use trusted checkpoints.

If deployment reports `bind source path does not exist: /opt/silvamang/models`, the image build succeeded but the server model directory has not been provisioned. This repository currently includes the required bundle. On the VPS, run the following from the Dokploy repository checkout (after the setup script is available there):

```sh
sudo sh docs/deployment/scripts/prepare_server_models.sh /opt/silvamang/models
```

The script checks all five source files before copying, skips identical existing files, refuses different existing files and prints SHA-256 checksums. It does not modify database data, credentials or Docker volumes. Keep `AI_MODELS_DIR=/opt/silvamang/models` and redeploy the same Dokploy application afterward. Creating an empty directory alone will satisfy the mount but will not provide working AI models.

3. On a Docker-capable validation host, with a **private** populated root `.env`:

```sh
docker compose config --quiet
docker compose build --pull
```

4. Deploy through Dokploy. Startup caches configuration/routes/views and starts Apache. It never runs migrations, seeders or key generation. For an existing database, review pending migrations and take a backup **before** the following explicit release step. Several existing migrations canonicalize/retire species records, so a normal `migrate` is not a substitute for review.

```sh
docker compose exec app php artisan migrate:status
docker compose exec app php artisan migrate --force
docker compose exec ai python docker/check-models.py
```

On a fresh database, `migrate:status` may report that the migrations table does not exist; run the reviewed `migrate --force` command. Inside the Dokploy `app` terminal, use just `php artisan ...`; in the `ai` terminal use `python docker/check-models.py`.

5. Existing installations: preserve users/roles/data; do not run the default seeder. Fresh installations: initialize roles explicitly with `php artisan db:seed --class=RoleSeeder --force`. Register your own account using the mobile app with a strong password, then open `php artisan tinker` in the app terminal and grant the role to the exact registered account:

```php
$user = App\Models\User::where('email', 'YOUR_REGISTERED_EMAIL')->firstOrFail();
$user->assignRole('super_admin');
```

Review and import the needed species/education/knowledge/model catalog data. Individual catalog seeders are in `database/seeders`; execute only reviewed seeders on an empty installation. **Do not run `DatabaseSeeder` or `AdminUserSeeder` in production**: they include known demo passwords and demo records. Do not automatically reseed during releases.

To fill the learning catalog and copy the bundled local iNaturalist reference cache after redeploying, run this in Dokploy's **app** terminal:

```sh
cd /var/www/html &&
php artisan db:seed --class=ProductionLearningSeeder --force &&
php artisan db:seed --class=ProductionBiodiversitySeeder --force
```

These scoped importers preserve existing learning content and reference records. The biodiversity snapshot contains 36 public observation references across five species, exported on October 2, 2026. It copies no users, credentials, scans, or local numeric IDs; species are matched by scientific name. Missing species or conflicting observation assignments abort and roll back the reference import. Repeating the import does not duplicate records or overwrite newer cached values. Photos remain remote URLs and require internet access. This is a one-time snapshot, not continuous synchronization; use **Refresh / Update Cache** in External Biodiversity Data for newer references or additional species.

6. Existing files belong under `storage/app/public`; exports under `storage/app/dataset`; existing `reports/efficientnet_transfer` contents under `storage/app/model-reports`. Fresh named volumes inherit UID 33 ownership from the image. When restoring files, retain/restore that ownership. The public storage symlink is baked into the image; the target remains persistent. Back up the whole app storage volume together with the database.
7. Build the signed mobile release separately, using a public-only mobile `.env` and:

```sh
flutter build appbundle --release --dart-define=API_BASE_URL=https://silvamangai.online/api
```

The build requires the Flutter SDK matching the project's Dart constraint and your existing Android signing setup. No backend API keys belong in bundled mobile environment files. iOS distribution needs its normal signing/provisioning workflow.
8. Before opening traffic, verify both domains, HTTPS redirects, login/session persistence, registration, upload/readback, API calls, CNN/YOLO/segmentation readiness, calibrated measurement, chatbot, reports and exports. `/api/health` and `/livez` are process liveness checks, not schema/model readiness guarantees. `check-models.py` exits nonzero for partial model readiness. Finally restart/redeploy and confirm the same users, uploads and exports remain.

## K. Validation and remaining release risks

Preparation checks executed locally:

| Check | Result |
| --- | --- |
| Laravel trusted/untrusted proxy regression tests | 2 passed, 4 assertions |
| Python health and calibrated measurement tests | 2 passed |
| Production Python liveness, disabled documentation endpoints and CORS checks | Passed |
| Flutter API URL regression tests | 4 passed |
| Vite production asset build | Passed |
| Laravel config, route and view caching with dummy configuration and temporary paths | Passed |
| Changed PHP syntax and production shell syntax | Passed |
| Compose YAML/service/port/network/environment structural checks | Passed |
| Tracked private environments and recognizable key/private-key patterns | None found in scanned tracked text files; not a full historical secret audit |
| `docker compose config` | Blocked: Docker CLI unavailable; standalone Compose download also stalled |
| Docker image builds and container persistence/restart checks | Not run: Docker engine unavailable |

Run `docker compose config --quiet` and `docker compose build --pull` on a Docker-capable host before deployment. Static checks are not proof of successful container deployment. No production database, DNS, deployment, commit or push was performed.

- Laravel 10 security support ended February 4, 2025. Plan and test a supported-framework upgrade before public launch: [official Laravel support policy](https://laravel.com/docs/10.x/releases#support-policy). This preparation preserves the existing framework and lockfile.
- Review dependency vulnerability audits and model accuracy on the target runtime before release. Production Python requirements pin direct runtime dependencies; transitive dependencies and base-image tags still resolve at build time. Retain tested image digests for rollback.
- Existing model/data changes and other uncommitted user work must be reviewed before a GitHub push. No commit/push is performed here. Ignore rules prevent new environment/secret files being added but cannot remove secrets from past Git history.
- Checkpoints and old training artifacts can be large. Runtime weights use the host mount, and old model copies are excluded from new Git additions. Review other large artifacts before pushing.
- The current default seeder is for demonstrations. Imported demo accounts must have their passwords changed or be disabled before public access.
- The old Render service and any existing database are not altered. DNS is managed externally.
