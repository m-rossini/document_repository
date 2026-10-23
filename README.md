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

See [OPERATIONS.md](OPERATIONS.md) for the full operations guide: start/stop,
feeding documents, backup/restore, and upgrades.

## Requirements

- Docker Engine with the Compose v2 plugin
- An x86-64 or ARM host with ~2 GB RAM free
