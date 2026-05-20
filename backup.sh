#!/bin/bash
set -e

# Load variables from .env
if [ -f .env ]; then
    # Use 'export' and 'eval' to ensure $HOME inside .env is expanded to the real path
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        export "$(eval echo "$line")"
    done < .env
fi
# --- Configuration ---
# Add your Rclone remotes here using the format "remote:folder_path"
# remote = the name chosen in 'rclone config'
# folder_path = the directory on your cloud storage
BACKUP_TARGETS=(
  "gdrive:searcheable_archive"
  "onedrive:searcheable_archive"
)

SOURCE_DIR="./export"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo "[$(date)] Starting backup process..."

# Step 0: Ensure export directory is clean and ready
mkdir -p "$SOURCE_DIR"

# Step 1: Run Paperless Exporter to generate human-readable filenames
# -na (no archive) and -nt (no thumbnail) are NOT used because 
# the user wants a "searcheable archive", so we need the OCR'd PDFs.
echo "Exporting documents with flat filenames..."
DOCKER_BIN=$(which podman 2>/dev/null || which docker 2>/dev/null)
# We add -na (no archive) to ensure we ONLY export the searchable ORIGINALS
# Paperless will only export the version it uses in the archive if we ask correctly.
$DOCKER_BIN exec document_repository_webserver_1 python3 manage.py document_exporter /usr/src/paperless/export -f -d -na -nt

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
CONFIGURED_REMOTES=$(rclone --config="$HOME/.config/rclone/rclone.conf" listremotes)

# Loop through internal targets
for TARGET in "${BACKUP_TARGETS[@]}"; do
    REMOTE_NAME=$(echo "$TARGET" | cut -d':' -f1)
    
    if echo "$CONFIGURED_REMOTES" | grep -q "^$REMOTE_NAME:"; then
        echo "Processing backup to $TARGET/$TIMESTAMP..."
        # We only copy .pdf files to keep it simple and clean
        rclone copy "$SOURCE_DIR" "$TARGET/$TIMESTAMP" \
            --config="$HOME/.config/rclone/rclone.conf" \
            --include "*.pdf" \
            --progress
    else
        echo "Skipping $REMOTE_NAME: Remote not configured in rclone."
    fi
done

echo "[$(date)] Backup process completed."
