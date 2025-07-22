## ClimWeb Docker Backup

This Docker setup creates and uploads a compressed `.tar.gz` backup of your specified folder to a remote (e.g. Google Drive) using Rclone.

### Requirements
- Docker and Docker Compose installed
- [Rclone installed](https://rclone.org/install/) **on the host** to create and test remotes
- A configured Rclone remote (run `rclone config` on your host)

### Setup
1. **Configure Rclone**
   ```bash
   rclone config
   ```
   Ensure your `~/.config/rclone/rclone.conf` file is available.

2. Make a copy of rclone config

    ```
    mkdir -p rclone_config
    
    cp ~/.config/rclone/rclone.conf rclone_config/
    ```

2. **Create a `.env` file**
   ```env
   REMOTE_FOLDER=gdrive:"climweb_backup/"
   ARCHIVE_FOLDER=backup.tar.gz
   BACKUP_DIR=/data
   ```

3. **Build and run the container**
   ```bash
   docker-compose build
   docker-compose up -d
   ```

### Notes
- Backups older than 3 days are deleted from the remote.
- Archives are stored in `/path/to/local/backup` on your host.
- Rclone config is mounted read-only from the host.

### Crontab
Adjust the `crontab` file to set the backup schedule. By default, it runs once daily (to be defined in the crontab file).
