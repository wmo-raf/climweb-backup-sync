#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# If SERVICE_ACCOUNT_JSON_B64 is set in the environment, decode it and write
# the service account JSON file so rclone can use it.
# This avoids having to SCP or transfer any files manually.
# ---------------------------------------------------------------------------
if [ -n "$SERVICE_ACCOUNT_JSON_B64" ]; then
  mkdir -p /config
  echo "$SERVICE_ACCOUNT_JSON_B64" | base64 -d > /config/service-account.json
  echo "[entrypoint] service-account.json written from SERVICE_ACCOUNT_JSON_B64"
fi

# Start cron and tail the log
exec crond -f -l 8 &
tail -F /var/log/backup.log
