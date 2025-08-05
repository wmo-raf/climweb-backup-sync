#!/bin/sh
set -e

TIMESTAMP=$(date +%F)
ARCHIVE_FILE="${TIMESTAMP}_backup.tar.gz"
REMOTE="${REMOTE_FOLDER}"
RCLONE_FLAGS="--config /root/.config/rclone/rclone.conf"

# Clean up old archive files
echo "Deleting local files matching *_backup.tar.gz ..."
rm -f *"_backup.tar.gz"

# Create tar.gz archive
echo "Creating archive ${ARCHIVE_FILE} from backup ..."
tar czf "${ARCHIVE_FILE}" /backup/

# Upload new archive
echo "Uploading ${ARCHIVE_FILE} to ${REMOTE} ..."
rclone $RCLONE_FLAGS copy "${ARCHIVE_FILE}" "${REMOTE}" \
  --progress \
  --transfers=1 \
  --drive-chunk-size=64M \
  --low-level-retries=10 \
  --retries=5 \
  --timeout=5m

# Delete old files from remote (>3 days old)
echo "Deleting old files from remote ..."
rclone $RCLONE_FLAGS delete --min-age 2d  --drive-use-trash=false "${REMOTE}"

echo "Sync complete."