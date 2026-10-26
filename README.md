# document_repo

Self-hosted [Paperless-ngx](https://docs.paperless-ngx.com/) — scan, OCR, index,
and search your documents. Everything runs locally via Docker Compose; no data
leaves the machine.

## Stack

| Service | Purpose |
|---------|---------|
| `webserver` | Paperless-ngx app + web UI (port 8000) |
| `db` | PostgreSQL 16 — metadata |
| `broker` | Redis 7 — task queue |
| `gotenberg` | Office → PDF conversion |
| `tika` | Extra text extraction (Office/ODF) |

All state is stored under `./data/` (gitignored). Configuration lives in
`docker-compose.env` (created from the template, also gitignored).

## Quickstart

```bash
make init     # create data dirs + docker-compose.env
# edit docker-compose.env: set PAPERLESS_SECRET_KEY and POSTGRES_PASSWORD
make up       # start the stack
make admin    # create your login
```

Then open <http://localhost:8000>.

Add documents by copying files into `data/consume/`:

```bash
make consume FILE=~/path/to/document.pdf
```

## Common commands

```
make help      # list all targets
make status    # service health
make logs      # follow logs
make backup    # DB dump + media archive into backups/
make down      # stop (data is preserved)
```

## Deploying to a remote host

Build and validate locally, ship over SSH, run on the remote. The remote needs
Docker Engine with Compose v2 and an SSH account — no clone, no build.

```bash
make remote-deploy REMOTE=user@host
```

`REMOTE` is a normal ssh destination. `SSH_PORT`, `SSH_OPTS`, and `REMOTE_DIR`
(default `~/document_repo`) are optional:

```bash
make remote-deploy REMOTE=user@host SSH_PORT=2222 REMOTE_DIR=/srv/paperless
```

Every local target has a `remote-` twin — `remote-up`, `remote-down`,
`remote-restart`, `remote-status`, `remote-logs`, `remote-admin`,
`remote-consume`, `remote-backup`, `remote-shell`, `remote-pull` — running the
same compose arguments on the remote. State stays in `REMOTE_DIR/data/`.

`docker-compose.env` is uploaded only when absent; set `REMOTE_ENV_FORCE=1` to
overwrite it. See [OPERATIONS.md](OPERATIONS.md#7-remote-deployment) for details.

See [OPERATIONS.md](OPERATIONS.md) for the full operations guide: start/stop,
feeding documents, backup/restore, and upgrades.

## Requirements

- Docker Engine with the Compose v2 plugin
- An x86-64 or ARM host with ~2 GB RAM free
