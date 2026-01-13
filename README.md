## ClimWeb Backup

This creates and uploads a compressed `.tar.gz` backup of your specified folder to a remote (e.g. Google Drive) using Rclone daily at midnight UTC + 00.

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

2. **Configure Rclone** - [install RClone first](https://rclone.org/install/) 
   ```bash
   rclone config
   ```

   answer as below:

   **New Remote**
   
    ```bash
    No remotes found, make a new one?
    n) New remote
    s) Set configuration password
    q) Quit config
    n/s/q> n
    ```


    **Remote name 'gdrive'**
   
   ```bash

   Enter name for new remote.
    name> gdrive
   ```

    **Storage type number corresponding to google drive e.g 18**

    ```bash
      \ (ftp)
    17 / Google Cloud Storage (this is not Google Drive)
       \ (google cloud storage)
    18 / Google Drive
       \ (drive)
    19 / Google Photos
       \ (google photos)
    20 / HTTP
       \ (http)
    
    ...
    Storage> 18
   ```

   **Client ID and Client Secret press 'enter' to leave empty**

    ```bash
    Option client_id.
    Google Application Client Id
    Setting your own is recommended.
    See https://rclone.org/drive/#making-your-own-client-id for how to create your own.
    If you leave this blank, it will use an internal key which is low performance.
    Enter a value. Press Enter to leave empty.
    client_id> 
    
    Option client_secret.
    OAuth Client Secret.
    Leave blank normally.
    Enter a value. Press Enter to leave empty.
    client_secret>
    ```

   **Scope select '3'**

   Option scope.

   ```bash
    Scope that rclone should use when requesting access from drive.
    Choose a number from below, or type in your own value.
    Press Enter to leave empty.
     1 / Full access all files, excluding Application Data Folder.
       \ (drive)
     2 / Read-only access to file metadata and file contents.
       \ (drive.readonly)
       / Access to files created by rclone only.
     3 | These are visible in the drive website.
       | File authorization is revoked when the user deauthorizes the app.
       \ (drive.file)
       / Allows read and write access to the Application Data folder.
     4 | This is not visible in the drive website.
       \ (drive.appfolder)
       / Allows read-only access to file metadata but
     5 | does not allow any access to read or download file content.
       \ (drive.metadata.readonly)
    scope> 3
   ```

   **Service account file press 'enter' to leave empty**
   
   Option service_account_file.
   
   ```bash
    Service Account Credentials JSON file path.
    Leave blank normally.
    Needed only if you want use SA instead of interactive login.
    Leading `~` will be expanded in the file name as will environment variables such as `${RCLONE_CONFIG_DIR}`.
    Enter a value. Press Enter to leave empty.
    service_account_file> 

   ```

   **Press enter to skip advanced configs**

   ```bash
    Edit advanced config?
    y) Yes
    n) No (default)
    y/n>
   ```

   **Autoconfig type 'n'**
   
   ```bash
   Use auto config?
     * Say Y if not sure
     * Say N if you are working on a remote or headless machine
    
    y) Yes (default)
    n) No
    y/n> n
   ```

   **Config Token (copy the rclone command and run it on your local machine)**
   Install rclone on your local machine first!
   
   ```bash
   Option config_token.
    For this to work, you will need rclone available on a machine that has
    a web browser available.
    For more help and alternate methods see: https://rclone.org/remote_setup/
    Execute the following on the machine with the web browser (same rclone
    version recommended):
            rclone authorize "drive" "eyJzY29wZSI6ImRyaXZlLmZpbGUifQ"
    Then paste the result.
    Enter a value.
    config_token>
   ```
   Locally select the gmail account to be connected to rclone and copy the token generated from the above command onto your remote server.

    **Shared Drive press 'enter' to leave empty**
   
   ```bash
    Configure this as a Shared Drive (Team Drive)?

    y) Yes
    n) No (default)
    y/n>
   ```
    
   **Keep drive type 'y**'

   ```bash
   - team_drive: 
    Keep this "gdrive" remote?
    y) Yes this is OK (default)
    e) Edit this remote
    d) Delete this remote
    y/e/d> y
   ```

   Completed successfully.
   
4. **Make a copy of rclone config**

    ```
    mkdir -p rclone_config

    cp ~/.config/rclone/rclone.conf rclone_config/
    ```

5. **Create a `.env` file** 

    ```
    cp .env.sample .env
    ```

    ```sh
    nano .env
    ```

    and edit below environmental variables appropriately

    ```env
    REMOTE_FOLDER="gdrive:climweb_backup/"
    BACKUP_DIR=/home/cms/climweb/climweb/backup/
    ```

6. **Build and run the container**

   ```bash
   docker compose up -d --build
   ```

### Notes
- Backups older than 3 days are deleted from the remote.
- Archives are stored in `/path/to/local/backup` on your host.
- Rclone config is mounted read-only from the host.

### Crontab
Adjust the `crontab` file to set the backup schedule. By default, it runs once daily (to be defined in the crontab file).
