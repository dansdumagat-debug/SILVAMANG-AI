# Database Backup and Restore Guide

Database:

```text
silvamang_ai
```

## Backup

```powershell
mysqldump -u root -p silvamang_ai > backups/silvamang_ai_backup.sql
```

## Restore

```powershell
mysql -u root -p silvamang_ai < backups/silvamang_ai_backup.sql
```

## Also Back Up

- `silvamang_api/storage/app/public`
- `dataset/`
- `silvamang_ai_service/models/`
- `silvamang_ai_service/reports/`

Do not include real passwords in backup documentation or shared files.
