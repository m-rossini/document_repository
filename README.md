# Document Archiving Pipeline

Automated document archiving system using **Paperless-ngx** for management and **Rclone** for secure, cloud-agnostic backups.

## Architectural Overview

1.  **Ingestion**: Files are dropped into `consume/`.
2.  **Processing**: Paperless-ngx OCRs the documents and moves them to `media/`.
3.  **Storage**: Metadata and indexes are stored in `data/`.
4.  **Backup**: A systemd timer triggers `backup.sh` daily, which uses Rclone to sync `media/documents/archive` (searchable PDFs) to your configured cloud remotes.

## Directory Structure

- `data/`: Stores database files, search indexes, and system configurations.
- `media/`: The document vault (originals vs the text-searchable `archive/` target PDFs).
- `consume/`: Local manual scanner and letter ingestion file drop-zone.
- `export/`: Temporary platform migration and bulk file exporting zone.
- `systemd/`: Houses the persistent automated scheduling service files.

## Setup Instructions

### Pre-requisites (WSL2 Ubuntu Users Only)

To support systemd in WSL2, ensure `/etc/wsl.conf` contains:

```ini
[boot]
systemd=true
```

Then restart WSL from PowerShell: `wsl --shutdown`.

### Quick Start

1.  **Initialize the Environment**:
    ```bash
    make setup
    ```
    This will install dependencies (Podman/Docker, Rclone), create folders, and generate a `.env` file with secure admin credentials.

2.  **Start the Services**:
    ```bash
    make start
    ```
    Access the system at `http://localhost:8000` (or the port defined in your `.env` as `PAPERLESS_PORT`).

### Ingestion Methods

1.  **Manual Drop-zone (Recommended)**:
    Simply drop your PDFs or images into the `consume/` folder. Paperless-ngx watches this directory and will automatically process and archive anything placed there.
2.  **Web Interface**:
    Use the "Upload Document" button at `http://localhost:8000`.
3.  **Email (Manual Configuration)**:
    If you wish to link an email account, it is recommended to do so directly via the Web UI (**Settings -> Mail Accounts**). Note that Gmail requires either an **App Password** or a custom **OAuth2** app created in the Google Cloud Console.

### Rclone Configuration

1.  **Authenticate a Remote**:
    ```bash
    rclone config
    ```
    Follow the prompts to add a new remote (e.g., `gdrive` or `onedrive`). Your tokens are stored locally on your host and never committed to Git.

2.  **Configure Backups**:
    Edit `backup.sh` and add your remote name and target folder to the `BACKUP_TARGETS` array using the format `remote:folder_name`.

    *   **remote**: The name you chose during `rclone config`.
    *   **folder_name**: The destination folder in your cloud storage (e.g., `My_Searchable_PDFs`).

    Example configurations:
    ```bash
    BACKUP_TARGETS=(
      "gdrive:My_Searchable_PDFs"
      "onedrive:Documents/Paperless_Archive"
    )
    ```

3.  **Test Backup**:
    ```bash
    make backup
    ```

## Security

This repository is **Zero-Secret**. No credentials, tokens, or documents are tracked by Git. All environment-specific variables are generated locally within `.env`.
