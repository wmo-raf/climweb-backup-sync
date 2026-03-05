#!/bin/bash

set -e

DATE=$(date +%F)

DEST_HOST=${DEST_PATH%%:*}
DEST_BASE=${DEST_PATH#*:}

DEST="$DEST_PATH/$DATE"

echo "Starting backup $DATE"

LINK_DEST=""

if ssh $DEST_HOST "[ -d $DEST_BASE/latest ]"; then
    LINK_DEST="--link-dest=$DEST_BASE/latest"
fi

# Determine SSH command
SSH_CMD="ssh"

if [ -n "$SSH_KEY_PATH" ]; then
  echo "Using custom SSH key: /root/ssh"
  SSH_CMD="ssh -i /root/ssh"
else
  echo "Using default SSH keys"
fi

echo "Using SSH command: $SSH_CMD"

rsync -az \
  -e="$SSH_CMD" \
  --delete \
  --partial --progress \
  $LINK_DEST \
  /backup/ \
  "$DEST_PATH/$DATE"

# update latest symlink
$SSH_CMD ${DEST_PATH%%:*} "ln -sfn $DEST $DEST_BASE/latest"

# keep only last 3 backups
$SSH_CMD ${DEST_PATH%%:*} "
cd $DEST_BASE &&
ls -dt */ 2>/dev/null | tail -n +4 | xargs -r rm -rf
"

echo "Backup completed $DATE"