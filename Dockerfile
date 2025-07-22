FROM alpine:latest

# Install required tools
RUN apk add --no-cache bash curl tar rclone

# Set environment variables
ARG BACKUP_DIR
ENV BACKUP_DIR=${BACKUP_DIR}

# Set working directory
WORKDIR /app

# Copy backup script
COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

# Copy crontab config
COPY crontab /etc/crontabs/root

# Create log file so tail doesn't fail
RUN touch /var/log/backup.log
# Run cron in foreground
CMD ["sh", "-c", "crond && tail -F /var/log/backup.log"]

