# Keep SILVAMANG scans and photos on Render

The API Docker image defaults to SQLite at `/var/www/html/database/database.sqlite`. Scan photos are written to Laravel's `public` disk, normally `/var/www/html/storage/app/public/scan-images`. Verified dataset exports default to `/var/www/dataset`. Those paths are inside the container unless a Render disk is mounted over them. Render preserves files **only under the disk's exact mount path**; attaching a disk starts a new deployment. See [Render persistent disks](https://render.com/docs/disks).

`GET /api/health` confirms that the web process responds. It does not check that the database or uploaded photos will survive a restart.

## 1. Check the live service before changing it

In the Render Dashboard, open the **SILVAMANG API web service**:

1. Under **Environment**, note `DB_CONNECTION`, `DB_DATABASE`, whether `DATABASE_URL` is set, `PUBLIC_STORAGE_ROOT`, `DATASET_EXPORT_ROOT`, and `SEED_ON_START`. Do not share the value of `DATABASE_URL` or any password.
2. Under **Disks**, note whether a disk exists and its **Mount path**. A disk at `/var/data` does not preserve files at `/var/www/html/storage/app/public` unless `PUBLIC_STORAGE_ROOT` points under `/var/data`.
3. Record the number of scans and transects shown in the admin dashboard. Open at least one scan with a photo and save its URL for comparison after the change.
4. If the service has Shell access, inspect the paths currently in use:

   ```sh
   printenv DB_CONNECTION DB_DATABASE PUBLIC_STORAGE_ROOT DATASET_EXPORT_ROOT SEED_ON_START
   ls -ld /var/www/html/storage/app/public /var/www/dataset /var/data 2>/dev/null || true
   ```

The image explicitly sets `DB_CONNECTION=sqlite`; a `DATABASE_URL` by itself is insufficient to switch this app to Postgres. Render's [Laravel Docker guide](https://render.com/docs/deploy-php-laravel-docker) sets both `DATABASE_URL` and `DB_CONNECTION=pgsql`.

## 2. Back up existing records and files first

**Do this before adding a disk, changing database variables, or redeploying.** An existing container-local SQLite file or photo directory can be lost when the old instance stops. A backup left in `/tmp` on the same service is also temporary; transfer it outside Render and verify that it can be read.

If the current service uses SQLite and its Shell page is available, create a consistent database copy and an archive of local scan photos:

```sh
sqlite3 "${DB_DATABASE:-/var/www/html/database/database.sqlite}" ".backup '/tmp/silvamang-before-move.sqlite'"
tar -czf /tmp/silvamang-photos-before-move.tar.gz -C /var/www/html/storage/app/public .
ls -lh /tmp/silvamang-before-move.sqlite /tmp/silvamang-photos-before-move.tar.gz
sqlite3 /tmp/silvamang-before-move.sqlite 'PRAGMA integrity_check; SELECT count(*) FROM scan_records;'
```

If the current public storage root is different, use that path in the `tar` command. Copy any existing verified dataset exports as well. Transfer the backups to a trusted machine with an approved secure transfer method such as Render SSH/SCP, and check their contents there. See Render's [file transfer instructions](https://render.com/docs/disks#transferring-files). If the service already uses Postgres, make a database backup using the database's backup/export method and separately back up the uploaded photo directory. Keep a copy of the current environment variable names and non-secret values.

Changing from an existing SQLite database to a new empty Postgres database will make existing records appear to disappear. It is a database migration, not an environment-only change. Restore or migrate the existing data and check record counts before moving traffic to the new database.

## 3. Choose one database arrangement

### A. Existing or new Render Postgres

Create or open the Render Postgres service and use its **internal database URL**. In the API web service's **Environment** page, set:

```env
DB_CONNECTION=pgsql
DATABASE_URL=<Render internal Postgres URL>
SEED_ON_START=false
```

Keep the real URL in Render's private environment settings. Do not paste it into source control or a screenshot. If scans are already stored in Postgres, keep pointing at the same database. If they are currently in SQLite, migrate the backed-up rows and relationships before switching the API.

Postgres protects database rows, but it does not store the uploaded photo bytes. For this app's current local `public` disk, attach a paid Render persistent disk with mount path `/var/data`, then set:

```env
PUBLIC_STORAGE_ROOT=/var/data/uploads
DATASET_EXPORT_ROOT=/var/data/dataset
```

Restore existing photos into `/var/data/uploads/scan-images/...`, preserving their paths relative to the old `storage/app/public` directory. Restore any dataset exports into `/var/data/dataset`. The app's `public/storage` link is recreated on startup and must resolve to the configured upload root.

### B. Existing SQLite, with one Render persistent disk

This is the shortest path when the current records are already in SQLite. On a **paid** API web service, open **Disks**, choose **Add Disk**, and enter `/var/data` as the **Mount path**. Then set these variables under **Environment**:

```env
DB_CONNECTION=sqlite
DB_DATABASE=/var/data/database.sqlite
PUBLIC_STORAGE_ROOT=/var/data/uploads
DATASET_EXPORT_ROOT=/var/data/dataset
SEED_ON_START=false
```

Restore the backed-up SQLite file to `/var/data/database.sqlite` and photos to `/var/data/uploads` before accepting new scans. Restore any existing dataset exports to `/var/data/dataset`. The running PHP user must be able to write to all three paths. Because adding a disk triggers a deploy, arrange the backup and restore as one controlled migration; do not depend on the old container still being available afterward.

Render does not attach persistent disks to free web services. For a free web service, use Postgres for records and a supported object storage integration for photos, or move the API to a paid service with a disk. The current scan upload code writes to the local `public` disk, so Postgres alone does not preserve photos. See [Render free tier limits](https://render.com/docs/free) and [persistent disk setup](https://render.com/docs/disks).

## 4. Verify after the change

1. In the Render service **Shell**, check that the configured paths are under the disk and writable: `df -h /var/data`, `test -w /var/data`, and `ls -ld /var/data/uploads /var/data/dataset`.
2. Compare scan and transect counts with the numbers recorded before migration. Check one older scan and open its original photo URL; a database row without its file will show a broken or missing image.
3. Create a new test scan with a photo, then restart or redeploy the API. Confirm that both the scan and photo still appear. Check `scan-images` on the disk if the photo does not load.
4. Confirm `SEED_ON_START=false`. Startup runs database migrations automatically. Seeding is for deliberate initialization of an empty database, not each deploy.
5. Keep a separate recurring backup of the database and uploaded files. A persistent disk protects against an ordinary redeploy, but it is not a substitute for backups.

Do not treat a successful `/api/health` response as proof of persistence. The record and photo checks above are the release checks for this change.
