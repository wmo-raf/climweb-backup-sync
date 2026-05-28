#!/bin/sh
set -e

# Start cron and tail the log
crond -f -l 8 &
tail -F /var/log/backup.log
