FROM alpine:latest

# Install required tools
RUN apk add --no-cache bash rsync openssh-client

# Set working directory
WORKDIR /app

# Copy backup script
COPY rsync_daily.sh /app/rsync_daily.sh
RUN chmod +x /app/rsync_daily.sh

# Copy crontab config
COPY crontab /etc/crontabs/root

# Create log file so tail doesn't fail
RUN touch /var/log/backup.log
# Run cron in foreground
CMD ["sh", "-c", "printenv > /etc/environment && crond && tail -F /var/log/backup.log"]
