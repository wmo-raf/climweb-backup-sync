## ClimWeb Cloud Backup

Uploads ClimWeb backups to a cloud remote using a storage-efficient strategy:

| Backup type | Frequency | Retention | Typical size |
|-------------|-----------|-----------|--------------|
| Database (`.psql.bin`) | Daily | 5 days | ~3–5 MB/file |
| Media (`.tar`) | Weekly | 1 snapshot | varies |

Files are uploaded individually with date-stamped names — nothing is ever overwritten.

---

## Options

| Option | Free storage | Credit card? | Best for |
|--------|-------------|-------------|----------|
| **Google Drive** ⭐ | 15 GB (shared) | No | Sites with a dedicated Google account |
| **OneDrive** | 5 GB | No | Sites with a Microsoft/Office 365 account |
| **Another server** | — | No | Strict data sovereignty requirements |

For backing up to another server via rsync, see [Backup To Remote Server Guide](./Backup-to-Remote-Server.md).

---

## Option 1 — Google Drive (Recommended)

Uses a service account — no OAuth browser flow, no SSH tunnel, no credit card. All steps are done in the Google Cloud web console and Google Drive. One-time setup of about 10 minutes.

> Use a **dedicated Google account for the site** rather than someone's personal account. The 15 GB is shared with Gmail and Google Photos.

### Step 1 — Enable the Drive API

1. Sign in to [https://console.cloud.google.com/](https://console.cloud.google.com/) with the site's Google account (no billing setup required)
2. **APIs & Services → Library** → search **Google Drive API** → Enable

### Step 2 — Create a service account and download its key

1. **IAM & Admin → Service Accounts → Create Service Account**
2. Give it a name (e.g. `climweb-backup`) → Create and continue → Done
3. Click the service account → **Keys tab → Add Key → Create new key → JSON** → Download

### Step 3 — Share a Google Drive folder with the service account

1. In Google Drive, create a folder (e.g. `ClimWeb Backups`)
2. Right-click the folder → **Share** → paste the service account email
   (looks like `climweb-backup@your-project.iam.gserviceaccount.com`) → set to **Editor** → Send

### Step 4 — Encode the key file

No file transfer needed. Convert the downloaded JSON to a single text string:

**Mac / Linux:**
```bash
base64 -w0 service-account.json
```

**Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json")) | clip
```

Copy the output (it will be a long single line of text).

### Step 5 — Clone and set environment variables

```bash
git clone https://github.com/wmo-raf/climweb-backup-sync.git
cd climweb-backup-sync
cp .env.sample .env
nano .env
```

```env
BACKUP_DIR=/home/user/climweb/climweb/backup
SITE_NAME=zambia
REMOTE_FOLDER=gdrive:ClimWeb Backups/
SERVICE_ACCOUNT_JSON_B64=<paste the base64 string here>
DB_RETENTION_DAYS=10
MEDIA_RETENTION_DAYS=3
MEDIA_UPLOAD_WEEKDAY=1
```

The container will decode and write the JSON file automatically at startup. No SCP, no file transfer.

### Step 6 — Copy the rclone config

```bash
cp rclone/config/rclone.conf.sample rclone/config/rclone.conf
```

The sample is already configured for Google Drive with a service account — no edits needed.

### Step 7 — Start the backup container

```bash
docker compose up -d climweb-backup-rclone
```

Done. Backups will upload daily at midnight UTC.

---

## Option 2 — OneDrive

Uses OAuth authentication via a temporary browser session. No credit card required — just a free Microsoft account. Requires a one-time SSH tunnel during setup.

### Step 1 — Clone the repository

```bash
git clone https://github.com/wmo-raf/climweb-backup-sync.git
cd climweb-backup-sync
```

### Step 2 — Start the setup container

```bash
docker compose --profile setup up climweb-backup-rclone-setup
```

### Step 3 — Open an SSH tunnel from your local machine

In a new terminal on your **local computer** (not the server):

```bash
ssh -L 5572:localhost:5572 user@your-server-ip
```

> Port 5572 is only bound on the server's internal localhost — it is not exposed externally and requires no firewall changes. All traffic flows through your existing SSH connection on port 22.

### Step 4 — Configure in your browser

Open [http://localhost:5572](http://localhost:5572) in your local browser. Click **Config** → **New remote** → choose **OneDrive** → complete the Microsoft sign-in. The token is saved to `rclone/config/rclone.conf` on the server.

### Step 5 — Stop the setup container

```bash
docker compose --profile setup down
```

### Step 6 — Set environment variables

```bash
cp .env.sample .env
nano .env
```

```env
BACKUP_DIR=/home/user/climweb/climweb/backup
SITE_NAME=zambia
REMOTE_FOLDER=onedrive:ClimWeb Backups/
DB_RETENTION_DAYS=10
MEDIA_RETENTION_DAYS=3
MEDIA_UPLOAD_WEEKDAY=1
```

> Note: OneDrive's free tier is 5 GB. With the default retention settings (~50 MB for DB + 1 weekly media snapshot) this is enough for most installations, but large media folders may require reducing `DB_RETENTION_DAYS`.

### Step 7 — Start the backup container

```bash
docker compose up -d climweb-backup-rclone
```

---

## Testing and logs

**Run a backup manually:**

```bash
docker exec -it climweb-backup-rclone /app/rclone_daily.sh
```

**View logs:**

```bash
docker logs climweb-backup-rclone
# or inside the container:
docker exec -it climweb-backup-rclone tail -f /var/log/backup.log
```

---

## Adjust the backup schedule

Edit `rclone/crontab` (default: midnight UTC):

```
0 0 * * * /app/rclone_daily.sh >> /var/log/backup.log 2>&1
```

Rebuild after changes:

```bash
docker compose up -d --build climweb-backup-rclone
```

---

## Remote storage layout

```
ClimWeb Backups/              (your Google Drive or OneDrive folder)
  db/
    zambia-db-2026-05-23.psql.bin
    zambia-db-2026-05-24.psql.bin
    ...
    zambia-db-2026-05-27.psql.bin   ← daily DB snapshots, ~3–5 MB each
  media/
    zambia-media-2026-05-26.tar     ← 1 weekly media snapshot
```

---

## Notes

- `rclone/config/rclone.conf` and `rclone/config/service-account.json` are git-ignored and should never be committed.
- Make sure `climweb dbbackup` and `climweb mediabackup` run before this container's cron job each day. The script uploads the most recent file it finds in the backup directory.
- To keep more media snapshots, increase `MEDIA_RETENTION_DAYS` — e.g. `28` keeps 4 weekly copies (uses ~4× the media file size on the remote).
