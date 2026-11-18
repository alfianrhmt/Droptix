#!/bin/sh
set -e

BACKUP_DIR="${BACKUP_DIR:-/backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="$BACKUP_DIR/droptix_backup_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting scheduled database backup..."

PGPASSWORD="$DB_PASSWORD" pg_dump \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --no-owner \
  --no-privileges \
  | gzip > "$FILENAME"

echo "[$(date)] Backup completed successfully: $FILENAME ($(du -h "$FILENAME" | cut -f1))"

# Hapus backup yang lebih tua dari 7 hari
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "droptix_backup_*.sql.gz" -type f -mtime +"$RETENTION_DAYS" -exec rm -f {} \;
echo "[$(date)] Cleanup finished."
