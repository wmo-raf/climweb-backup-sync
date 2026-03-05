# Developer Guide: Automated Climweb Backup from one server to another

## Overview

This guide explains how to set up an automated daily climweb backup system using:

* **Docker**
* **rsync**
* **SSH key authentication**
* **cron scheduling**

The system runs on a **source server** and sends backups to a **destination server** every day at midnight.

### Architecture

```
Source Server
   Docker container
       cron
         ↓
       rsync
         ↓ (SSH)
Destination Server
   /data/backups/
```

The backup system:

* runs **daily at midnight**
* creates **daily snapshot backups**
* keeps **only the last 3 backups**
* uses **SSH keys (no password required)**

### Requirements
- Docker Engine & Docker Compose Plugin : Ensure that Docker Engine is installed and running on the machine where you plan to execute the docker-compose command https://docs.docker.com/engine/install/. Docker Engine is the runtime environment for containers.

---

## 1. Clone repository

    ```
    git clone https://github.com/wmo-raf/climweb-backup-sync.git
    ```

    ```
    cd climweb-backup-sync
    ```

## 2. Verify or Create SSH Keys (Source Server)

Login to the **source server** (where climweb is installed).

Check if SSH keys already exist:

```bash
ls -al ~/.ssh
```

Typical output:

```
id_ed25519
id_ed25519.pub
authorized_keys
known_hosts
```

If `id_ed25519` and `id_ed25519.pub` exist, you already have SSH keys.

---

### If no keys exist

Generate a new key pair:

```bash
ssh-keygen -t ed25519
```

Press **Enter** for all defaults.

This creates:

```
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

| File           | Purpose                                   |
| -------------- | ----------------------------------------- |
| id_ed25519     | Private key (keep secret)                 |
| id_ed25519.pub | Public key (copied to destination server) |

---

## 3. Install SSH Key on Destination Server

From the **source server**, copy the key to the destination server:

```bash
ssh-copy-id user@destination_ip
```

Example:

```bash
ssh-copy-id backup@192.168.1.20
```

This adds your key to:

```
~/.ssh/authorized_keys
```

on the destination server.

---

## 4. Test SSH Access

Test login from the source server:

```bash
ssh user@destination_ip
```

If login works **without a password**, the SSH key setup is correct.

Exit the session:

```bash
exit
```

---

## 5. Prepare Backup Directory (Destination Server)

Login to the destination server:

```bash
ssh user@destination_ip
```

Create the backup directory:

```bash
mkdir -p /data/backups && mkdir -p /data/backups/latest
```

Set permissions:

```bash
chmod 755 /data/backups
```

---

## 6. Environment Configuration

Create a `.env` file:

```bash
cp .env.sample .env
```

edit the .env file with correct variables

```bash
nano .env
```

```env
BACKUP_DIR=/home/user/climweb/climweb/backup
DEST_PATH=user@destination_ip:/data/backups
```

| Variable   | Purpose                         |
| ---------- | ------------------------------- |
| BACKUP_DIR | Directory to climweb backup     |
| DEST_PATH  | Destination server path         |
| SSH_KEY_PATH *(Optional if your key is not saved at ~/.ssh)*  | Destination server path         |

---

## 7. Build and Start the Container

Build container and start the service:

```bash
   docker compose up -d --build climweb-backup-rsync
```

Verify container is running:

```bash
docker ps
```

---

## 8. View Logs

View container logs:

```bash
docker logs climweb-backup-rsync
```

Or inside the container:

```bash
tail -f /var/log/backup.log
```

---

# Test the Backup Manually (optional)

Run the backup manually:

```bash
docker exec -it climweb-backup-rsync /app/rsync_daily.sh
```

Verify on the destination server:

```bash
ssh user@destination_ip
ls /data/backups
```

Expected output:

```
/data/backups
├── 2026-03-05
└── latest -> 2026-03-05
```

