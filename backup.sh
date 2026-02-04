#!/bin/sh
set -e

ARCHIVE_FILE="backup.tar.gz"
REMOTE="${REMOTE_FOLDER}"
RCLONE_FLAGS="--config /root/.config/rclone/rclone.conf"

WORKDIR="/tmp/backup_upload"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "Creating archive..."
tar czf "$WORKDIR/$ARCHIVE_FILE" /backup/

echo "Syncing backup to remote..."
rclone $RCLONE_FLAGS sync "$WORKDIR" "$REMOTE" \
  --progress \
  --transfers=1 \
  --low-level-retries=10 \
  --retries=5 \
  --timeout=5m

echo "Backup complete."
