FROM alpine:latest

# Install required tools
RUN apk add --no-cache bash curl tar rclone

# Set working directory
WORKDIR /app

# Copy backup script
COPY rclone_daily.sh /app/rclone_daily.sh
RUN chmod +x /app/rclone_daily.sh

# Copy crontab config
COPY crontab /etc/crontabs/root

# Create log file so tail doesn't fail
RUN touch /var/log/backup.log
# Run cron in foreground
CMD ["sh", "-c", "crond && tail -F /var/log/backup.log"]

