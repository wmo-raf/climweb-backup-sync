FROM alpine:latest

# Install required tools
RUN apk add --no-cache bash curl tar rclone

WORKDIR /app

COPY rclone_daily.sh /app/rclone_daily.sh
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/rclone_daily.sh /app/entrypoint.sh

COPY crontab /etc/crontabs/root

RUN touch /var/log/backup.log

# rclone config is mounted at /config/rclone.conf (see docker-compose.yml)
# service-account.json is written at startup from SERVICE_ACCOUNT_JSON_B64
ENTRYPOINT ["/app/entrypoint.sh"]
