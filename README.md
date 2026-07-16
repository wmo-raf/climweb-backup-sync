> # ⚠️ Archived — superseded by in-CMS backups
>
> **This repository is no longer maintained.** Cloud backups to Google Drive are
> now built directly into the ClimWeb CMS admin, under **Settings → Backup** — no
> command line, no separate container, and set up per site from the browser.
>
> Use that instead. See the setup guide in the ClimWeb repo at
> `climweb/src/climweb/base/backups/README.md` (also linked from the Backup
> settings page in the admin).
>
> This repo is kept only for reference and for existing rsync-to-another-server
> setups that haven't migrated yet.

---

## ClimWeb Cloud Backup

Uploads ClimWeb backups to a cloud remote using a storage-efficient strategy:

| Backup type | Frequency | Retention | Typical size |
|-------------|-----------|-----------|--------------|
| Database (`.psql.bin`) | Daily | 10 days | ~3–5 MB/file |
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

Uses OAuth — no credit card required, just a Google account. You run `rclone authorize` once on your local machine to generate a token, paste it into a config file on the server, and you're done.

> Use a **dedicated Google account for the site** rather than someone's personal account. The 15 GB quota is shared with Gmail and Google Photos.

### Step 1 — Install rclone on your local machine (one-time)

**Mac:**
```bash
brew install rclone
```

**Windows:** Download the installer from [https://rclone.org/downloads/](https://rclone.org/downloads/)

**Linux:**
```bash
sudo -v ; curl https://rclone.org/install.sh | sudo bash
```

### Step 2 — Generate the token

On your local machine:

```bash
rclone authorize "drive"
```

Your browser will open automatically. Sign in with the site's Google account and approve access. Rclone prints the token to your terminal:

```
Paste the following into your remote machine --->
{"access_token":"ya29...","token_type":"Bearer","refresh_token":"1//...","expiry":"..."}
<---End paste
```

Copy that JSON (the `{...}` part).

### Step 3 — Clone the repository and write the config

On the server:

```bash
git clone https://github.com/wmo-raf/climweb-backup-sync.git
cd climweb-backup-sync
```

Create `rclone/config/rclone.conf` with the token you copied:

```ini
[gdrive]
type = drive
scope = drive.file
token = PASTE_TOKEN_JSON_HERE
```

Replace `PASTE_TOKEN_JSON_HERE` with the `{"access_token":...}` JSON on a single line.

### Step 4 — Set environment variables

```bash
cp .env.sample .env
nano .env
```

```env
BACKUP_DIR=/home/user/climweb/climweb/backup
SITE_NAME=zambia
REMOTE_FOLDER=gdrive:ClimWeb Backups/
DB_RETENTION_DAYS=10
MEDIA_RETENTION_DAYS=3
MEDIA_UPLOAD_WEEKDAY=1
```

### Step 5 — Start the backup container

```bash
docker compose up -d climweb-backup-rclone --build
```

Done. Backups will upload daily at midnight UTC.

---

## Option 2 — OneDrive

Same approach as Google Drive — run `rclone authorize` locally once, paste the token into the server config.

### Step 1 — Install rclone on your local machine (one-time)

See Option 1 Step 1.

### Step 2 — Generate the token

On your local machine:

```bash
rclone authorize "onedrive"
```

Your browser will open. Sign in with the Microsoft account. Copy the token JSON printed to your terminal.

### Step 3 — Clone the repository and write the config

On the server:

```bash
git clone https://github.com/wmo-raf/climweb-backup-sync.git
cd climweb-backup-sync
```

Create `rclone/config/rclone.conf`:

```ini
[onedrive]
type = onedrive
token = PASTE_TOKEN_JSON_HERE
drive_id = YOUR_DRIVE_ID
drive_type = personal
```

> To find your `drive_id`: run `rclone config` on your local machine, follow the OneDrive setup, and rclone will display and save the drive ID automatically. Copy the full `[onedrive]` section from `~/.config/rclone/rclone.conf` to the server.

> Note: OneDrive's free tier is 5 GB. With the default retention settings (~50 MB for DB + 1 weekly media snapshot) this is enough for most installations, but large media folders may require reducing `DB_RETENTION_DAYS`.

### Step 4 — Set environment variables

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

### Step 5 — Start the backup container

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

- `rclone/config/rclone.conf` is git-ignored and should never be committed.
- Make sure `climweb dbbackup` and `climweb mediabackup` run before this container's cron job each day. The script uploads the most recent file it finds in the backup directory.
- To keep more media snapshots, increase `MEDIA_RETENTION_DAYS` — e.g. `28` keeps 4 weekly copies (uses ~4× the media file size on the remote).
