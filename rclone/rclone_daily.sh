#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# ClimWeb → Cloud Backup (rclone)
#
# Storage-efficient strategy:
#   DB backup   — uploaded DAILY   with a date stamp, small (~3–5 MB each)
#   Media backup — uploaded WEEKLY  with a date stamp, large but infrequent
#
# This avoids re-archiving everything into one big file each day, which would
# fill even a free Google Drive (15 GB) or OneDrive (5 GB) quickly.
#
# Remote folder layout:
#   <REMOTE_FOLDER>/
#     db/    zambia-db-2026-05-27.psql.bin   (30 days kept)
#     media/ zambia-media-2026-05-24.tar     (4 weeks kept)
# ---------------------------------------------------------------------------

DATE=$(date +%Y-%m-%d)
DOW=$(date +%u)          # 1=Monday … 7=Sunday

SITE_NAME="${SITE_NAME:-climweb}"
REMOTE="${REMOTE_FOLDER}"
RCLONE_FLAGS="--config /config/rclone.conf"

DB_RETENTION_DAYS="${DB_RETENTION_DAYS:-10}"
MEDIA_RETENTION_DAYS="${MEDIA_RETENTION_DAYS:-3}"   # 3 days = 1 weekly snapshot
MEDIA_UPLOAD_WEEKDAY="${MEDIA_UPLOAD_WEEKDAY:-1}"    # 1 = Monday

DB_REMOTE="${REMOTE}db/"
MEDIA_REMOTE="${REMOTE}media/"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# ---------------------------------------------------------------------------
# DB backup — every day
# ---------------------------------------------------------------------------
DB_FILE=$(ls -t /backup/*.psql.bin 2>/dev/null | head -1 || true)

if [ -z "$DB_FILE" ]; then
  log "WARNING: No .psql.bin file found in /backup — skipping DB upload."
else
  DB_DEST="${DB_REMOTE}${SITE_NAME}-db-${DATE}.psql.bin"
  log "Uploading DB backup → $DB_DEST"
  rclone $RCLONE_FLAGS copyto "$DB_FILE" "$DB_DEST" \
    --transfers=1 --retries=5 --timeout=10m

  log "Removing DB backups older than ${DB_RETENTION_DAYS} days from remote..."
  rclone $RCLONE_FLAGS delete "$DB_REMOTE" \
    --min-age "${DB_RETENTION_DAYS}d" 2>/dev/null || true

  log "DB backup complete."
fi

# ---------------------------------------------------------------------------
# Media backup — once per week (on MEDIA_UPLOAD_WEEKDAY)
# ---------------------------------------------------------------------------
if [ "$DOW" = "$MEDIA_UPLOAD_WEEKDAY" ]; then
  MEDIA_FILE=$(ls -t /backup/*.tar 2>/dev/null | head -1 || true)

  if [ -z "$MEDIA_FILE" ]; then
    log "WARNING: No .tar file found in /backup — skipping media upload."
  else
    MEDIA_DEST="${MEDIA_REMOTE}${SITE_NAME}-media-${DATE}.tar"
    log "Uploading media backup → $MEDIA_DEST"
    rclone $RCLONE_FLAGS copyto "$MEDIA_FILE" "$MEDIA_DEST" \
      --transfers=1 --retries=5 --timeout=30m

    log "Removing media backups older than ${MEDIA_RETENTION_DAYS} days from remote..."
    rclone $RCLONE_FLAGS delete "$MEDIA_REMOTE" \
      --min-age "${MEDIA_RETENTION_DAYS}d" 2>/dev/null || true

    log "Media backup complete."
  fi
else
  log "Skipping media upload (runs on weekday ${MEDIA_UPLOAD_WEEKDAY}, today is ${DOW})."
fi

log "Done."
