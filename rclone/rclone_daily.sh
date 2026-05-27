#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# ClimWeb → Cloud Backup (rclone)
#
# Storage-efficient strategy:
#   DB backup    — uploaded DAILY  with a date stamp, small (~3–5 MB each)
#   Media backup — uploaded WEEKLY with a date stamp, large but infrequent
#
# Remote folder layout:
#   <REMOTE_FOLDER>/
#     db/     zambia-db-2026-05-27.psql.bin
#             zambia-manifest-2026-05-27.json   ← version recorded alongside DB
#     media/  zambia-media-2026-05-26.tar
# ---------------------------------------------------------------------------

DATE=$(date +%Y-%m-%d)
DOW=$(date +%u)          # 1=Monday … 7=Sunday

SITE_NAME="${SITE_NAME:-climweb}"
REMOTE="${REMOTE_FOLDER}"
RCLONE_FLAGS="--config /config/rclone.conf"

DB_RETENTION_DAYS="${DB_RETENTION_DAYS:-10}"
MEDIA_RETENTION_DAYS="${MEDIA_RETENTION_DAYS:-3}"
MEDIA_UPLOAD_WEEKDAY="${MEDIA_UPLOAD_WEEKDAY:-1}"

DB_REMOTE="${REMOTE}db/"
MEDIA_REMOTE="${REMOTE}media/"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# ---------------------------------------------------------------------------
# Resolve the running climweb version from files already in the backup volume.
# No coupling to climweb-docker needed — these files are written automatically:
#   upgrade-status.json  — written by cms-upgrade.sh on every upgrade
#   backup-manifest.json — written by scripts/backup.sh (manual / pre-upgrade)
# ---------------------------------------------------------------------------
CLIMWEB_VERSION="unknown"

# Primary: upgrade-status.json is always present and reflects the current version
if [ -f "/backup/upgrade-status.json" ]; then
  V=$(grep '"to_version"' /backup/upgrade-status.json \
      | sed 's/.*"to_version": *"\([^"]*\)".*/\1/' 2>/dev/null || true)
  [ -n "$V" ] && CLIMWEB_VERSION="$V"
fi

# Fallback: backup-manifest.json written by scripts/backup.sh
if [ "$CLIMWEB_VERSION" = "unknown" ] && [ -f "/backup/backup-manifest.json" ]; then
  V=$(grep '"climweb_version"' /backup/backup-manifest.json \
      | sed 's/.*"climweb_version": *"\([^"]*\)".*/\1/' 2>/dev/null || true)
  [ -n "$V" ] && CLIMWEB_VERSION="$V"
fi

log "ClimWeb version: $CLIMWEB_VERSION"

# ---------------------------------------------------------------------------
# Write/refresh backup-manifest.json in the backup volume.
# This keeps the local manifest up to date even for automated Celery backups
# that do not call scripts/backup.sh directly.
# ---------------------------------------------------------------------------
DB_FILE=$(ls -t /backup/*.psql.bin 2>/dev/null | head -1 || true)
MEDIA_FILE=$(ls -t /backup/*.tar 2>/dev/null | head -1 || true)

cat > /backup/backup-manifest.json << EOF
{
  "climweb_version": "$CLIMWEB_VERSION",
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "db_file": "$(basename "${DB_FILE:-unknown}")",
  "media_file": "$(basename "${MEDIA_FILE:-unknown}")"
}
EOF
log "backup-manifest.json refreshed (version: $CLIMWEB_VERSION)"

# ---------------------------------------------------------------------------
# DB backup — every day
# ---------------------------------------------------------------------------
if [ -z "$DB_FILE" ]; then
  log "WARNING: No .psql.bin file found in /backup — skipping DB upload."
else
  DB_DEST="${DB_REMOTE}${SITE_NAME}-db-${DATE}.psql.bin"
  MANIFEST_DEST="${DB_REMOTE}${SITE_NAME}-manifest-${DATE}.json"

  log "Uploading DB backup → $DB_DEST"
  rclone $RCLONE_FLAGS copyto "$DB_FILE" "$DB_DEST" \
    --transfers=1 --retries=5 --timeout=10m

  log "Uploading manifest → $MANIFEST_DEST"
  rclone $RCLONE_FLAGS copyto /backup/backup-manifest.json "$MANIFEST_DEST" \
    --transfers=1 --retries=3 --timeout=1m

  log "Removing DB/manifest files older than ${DB_RETENTION_DAYS} days from remote..."
  rclone $RCLONE_FLAGS delete "$DB_REMOTE" \
    --min-age "${DB_RETENTION_DAYS}d" 2>/dev/null || true

  log "DB backup complete."
fi

# ---------------------------------------------------------------------------
# Media backup — once per week (on MEDIA_UPLOAD_WEEKDAY)
# ---------------------------------------------------------------------------
if [ "$DOW" = "$MEDIA_UPLOAD_WEEKDAY" ]; then
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
