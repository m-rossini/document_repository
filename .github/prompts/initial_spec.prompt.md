---
name: initial_spec
description: Initial Specs for the project
---

Act as an expert Linux Platform Engineer. I need you to generate a fully automated, cross-distro, and zero-secret repository structure for a document archiving pipeline using Paperless-ngx and Rclone. 

The codebase must be 100% free of hardcoded credentials or authorization tokens so it can be safely pushed to a public GitHub repository. It must seamlessly support native Fedora environments (with strict SELinux enforcement) and Windows Subsystem for Linux (WSL2 running Ubuntu).

Please generate the exact code and configuration for the following files:

1. `.gitignore`
- Must block all local document storage folders, database locations, runtime logs, and the local `.env` file from tracking.

2. `Makefile`
- Must dynamically detect the host package manager ('dnf' for Fedora/RHEL, 'apt-get' for Debian/Ubuntu).
- Must dynamically detect the container runtime command ('podman' or 'docker').
- Target `setup`: Must update packages, install the detected container engine, its compose engine, curl, and unzip. Must run the official upstream Rclone installer script ('curl https://rclone.org/install.sh | sudo bash'). Must provision local project folders. If a local '.env' file doesn't exist, it must automatically generate one containing 'PAPERLESS_ADMIN_USER=admin' and a cryptographically secure 16-character 'PAPERLESS_ADMIN_PASSWORD' using standard bash tools, output them to the terminal console, and write them to the hidden local file. Finally, it must call the service initialization and systemd targets.
- Target `start`: Boots the compose containers in decoupled mode.
- Target `install-timer`: Copies systemd files to the local user target (~/.config/systemd/user/) and activates the persistent daily background schedule.
- Target `backup`: Runs the local backup wrapper file.

3. `compose.yaml`
- Must feature a clean Redis 7 cache service and the latest Paperless-ngx web server instance.
- Must bind local storage maps for './data', './media', './export', and './consume'.
- CRUCIAL FOR FEDORA SELINUX: All volume mounts must explicitly append the private SELinux volume relabel flag ':Z' (e.g., './data:/usr/src/paperless/data:Z'). The consume and export folders must also feature the owner-mapping flag ':Z,U' so the container runtime can read and write local host files without host security permission failures.
- Must inherit environment variables natively from the dynamically generated local '.env' configuration file.

4. `backup.sh`
- Must be a robust, error-tolerant bash script ('set -e').
- Must define a flexible array variable named 'BACKUP_TARGETS' that allows the user to easily comment/uncomment to switch between a single cloud destination (e.g., "gdrive:My_Searchable_PDFs") OR multiple different cloud providers simultaneously.
- Must loop through this array, utilize 'rclone listremotes' to verify the target cloud company is authenticated on the host machine, and perform an immutable 'rclone copy' from the searchable local index folder ('./media/documents/archive') to the cloud destination. Unconfigured backends must be skipped gracefully without returning error codes.

5. `systemd/paperless-backup.service` & `systemd/paperless-backup.timer`
- Service file must point directly to the absolute home user directory execution string of the 'backup.sh' script as a 'oneshot' job.
- Timer file must run daily, contain 'Persistent=true' to execute missed backups if the machine was offline, and bind into the 'timers.target' cycle.

6. `README.md`
- Must include an architectural overview explaining the automated ingestion workflow.
- Must detail the exact purpose of every folder in the structure:
  * 'data/': Stores database engine files, search indexes, and system configurations.
  * 'media/': The document vault (originals vs the text-searchable 'archive/' target PDFs).
  * 'consume/': The local manual scanner and letter ingestion file drop-zone.
  * 'export/': Temporary platform migration and bulk file exporting zone.
  * 'systemd/': Houses the persistent automated scheduling service files.
- Must explicitly instruct the user on how to prepare WSL2 (Ubuntu) to support systemd by modifying '/etc/wsl.conf' with the '[boot]\nsystemd=true' flag followed by a PowerShell 'wsl --shutdown'.
- Must document the step-by-step instructions for initializing manual host authentications using 'rclone config' for both a single provider setup and a multi-cloud configuration, emphasizing that cloud tokens are kept entirely safe from public Git tracking.

Provide the direct, production-ready code blocks for each file clearly without burying them inside unnecessary explanations.