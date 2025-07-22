#!/bin/sh
set -e

TIMESTAMP=$(date +%F)
ARCHIVE_FILE="${TIMESTAMP}_${ARCHIVE_FOLDER}"
REMOTE="${REMOTE_FOLDER}"

cd /backup || exit 1

# Clean up old archive files
echo "Deleting local files matching *_${ARCHIVE_FOLDER} ..."
rm -f *"_${ARCHIVE_FOLDER}"

# Delete old files from remote (>3 days old)
echo "Deleting old files from remote ..."
rclone delete --min-age 3d "${REMOTE}"

# Create tar.gz archive
echo "Creating archive ${ARCHIVE_FILE} from ${BACKUP_DIR} ..."
tar czf "${ARCHIVE_FILE}" .

# Upload new archive
echo "Uploading ${ARCHIVE_FILE} to ${REMOTE} ..."
rclone copy "${ARCHIVE_FILE}" "${REMOTE}" \
  --progress \
  --transfers=1 \
  --drive-chunk-size=64M \
  --low-level-retries=10 \
  --retries=5 \
  --timeout=5m

echo "Sync complete."