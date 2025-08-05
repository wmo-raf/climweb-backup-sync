## ClimWeb Backup

This creates and uploads a compressed `.tar.gz` backup of your specified folder to a remote (e.g. Google Drive) using Rclone daily at midnight.

### Requirements
- Docker Engine & Docker Compose Plugin : Ensure that Docker Engine is installed and running on the machine where you plan to execute the docker-compose command https://docs.docker.com/engine/install/. Docker Engine is the runtime environment for containers.
- [Rclone installed](https://rclone.org/install/) **on the host** to create and test remotes
- A configured Rclone remote (run `rclone config` on your host)

### Setup
1. **Clone repository**

    ```
    git clone https://github.com/wmo-raf/climweb-backup-sync.git
    ```

    ```
    cd climweb-backup-sync
    ```

2. **Configure Rclone**
   ```bash
   rclone config
   ```
   
   Ensure your `~/.config/rclone/rclone.conf` file is available.

3. **Make a copy of rclone config**

    ```
    mkdir -p rclone_config

    cp ~/.config/rclone/rclone.conf rclone_config/
    ```

4. **Create a `.env` file**

    ```
    cp .env.sample .env
    ```

    and edit below environmental variables

    ```env
    REMOTE_FOLDER="gdrive:climweb_backup/"
    BACKUP_DIR=/home/cms/climweb/climweb/backup/
    ```

5. **Build and run the container**

   ```bash
   docker compose up -d --build
   ```

### Notes
- Backups older than 3 days are deleted from the remote.
- Archives are stored in `/path/to/local/backup` on your host.
- Rclone config is mounted read-only from the host.

### Crontab
Adjust the `crontab` file to set the backup schedule. By default, it runs once daily (to be defined in the crontab file).
