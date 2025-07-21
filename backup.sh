#!/bin/sh
TIMESTAMP=$(date +%F)
REMOTE="${REMOTE_FOLDER}"

echo "Deleting old files ..."
rm *"_${ARCHIVE_FOLDER}"
rclone delete --min-age 3d "${REMOTE}"
tar czf "${TIMESTAMP}_${ARCHIVE_FOLDER}" "$BACKUP_DIR"

echo "Uploading new files from $BACKUP_DIR..."
rclone copy "${TIMESTAMP}_${ARCHIVE_FOLDER}" "$REMOTE" \
  --progress \
  --transfers=1 \
  --drive-chunk-size=64M \
  --low-level-retries=10 \
  --retries=5 \
  --timeout=5m 


echo "Sync complete."