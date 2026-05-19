#!/bin/bash
set -e

# --- Configuration ---
# Add your Rclone remotes here using the format "remote:folder_path"
# remote = the name chosen in 'rclone config'
# folder_path = the directory on your cloud storage
BACKUP_TARGETS=(
  # "gdrive:My_Searchable_PDFs"
  # "onedrive:Documents/Paperless_Archive"
)

SOURCE_DIR="./media/documents/archive"

echo "[$(date)] Starting backup process..."

if [ ${#BACKUP_TARGETS[@]} -eq 0 ]; then
    echo "Warning: No backup targets configured in BACKUP_TARGETS array."
    echo "Please edit backup.sh to add your cloud remotes."
    exit 0
fi

echo "Configured targets:"
for T in "${BACKUP_TARGETS[@]}"; do echo "  - $T"; done

# Verify if Rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "Error: rclone is not installed."
    exit 1
fi

# Get list of configured remotes
CONFIGURED_REMOTES=$(rclone listremotes)

# Loop through internal targets
for TARGET in "${BACKUP_TARGETS[@]}"; do
    REMOTE_NAME=$(echo "$TARGET" | cut -d':' -f1)
    
    if echo "$CONFIGURED_REMOTES" | grep -q "^$REMOTE_NAME:"; then
        echo "Processing backup to $TARGET..."
        rclone copy "$SOURCE_DIR" "$TARGET" --progress
    else
        echo "Skipping $REMOTE_NAME: Remote not configured in rclone."
    fi
done

echo "[$(date)] Backup process completed."
