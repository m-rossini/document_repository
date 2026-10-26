# Operations Guide

Day-to-day operation of the local Paperless-ngx stack. All commands run from the
project root and go through the `Makefile` (`make help` lists everything).

## 1. First-time setup

```bash
make init     # creates ./data/* dirs and docker-compose.env from the template
```

Then edit `docker-compose.env` and set:

- `PAPERLESS_SECRET_KEY` — generate with `openssl rand -base64 48`
- `POSTGRES_PASSWORD` — any strong password

Start the stack and create the admin user:

```bash
make up
make admin    # interactive: username / email / password
```

Open <http://localhost:8000> and log in.

## 2. Start / stop

| Task | Command |
|------|---------|
| Start (detached) | `make up` |
| Stop (keep data) | `make down` |
| Restart services | `make restart` |
| Check status | `make status` |
| All logs | `make logs` |
| Webserver logs only | `make logs-web` |
| Shell in container | `make shell` |

`make down` removes containers but **never** deletes `./data/`. Documents, the
database, and the search index survive restarts.

## 3. Feeding documents in

Drop files into `data/consume/` and Paperless imports them automatically
(polled ~every 10s). To copy a file in from anywhere:

```bash
make consume FILE=~/Downloads/invoice.pdf
```

You can also upload through the web UI, or `cp` several files into
`data/consume/` at once. Files are OCRed (`por+eng`) and become searchable
within about a minute.

## 4. Backup

```bash
make backup
```

Creates `backups/YYYYMMDD-HHMM/` containing:

- `db.sql` — full PostgreSQL dump
- `media.tar.gz` — the original + archived documents

Run it before upgrades or risky changes. Copy backups off this machine for real
safety.

## 5. Restore

1. Stop the stack: `make down`
2. Restore media: `tar -xzf backups/<stamp>/media.tar.gz -C .` (writes into `data/`)
3. Start only the database: `docker compose --env-file docker-compose.env up -d db`
4. Load the dump:
   ```bash
   docker compose --env-file docker-compose.env exec -T db \
     psql -U paperless -d paperless < backups/<stamp>/db.sql
   ```
5. Start everything: `make up`

## 6. Upgrades

```bash
make backup
make pull
make up
```

Paperless runs migrations automatically on startup.

## 7. Remote deployment

Same stack, run on another machine. The bundle is validated locally, copied over
SSH, and started there — the project is never cloned or built on the remote.

**Remote requirements:** Docker Engine with the Compose v2 plugin, plus an SSH
account that can run `docker`.

**Settings** — pass per command or `export` them:

| Variable | Default | Meaning |
|----------|---------|---------|
| `REMOTE` | *(required)* | ssh destination, e.g. `user@host` |
| `SSH_PORT` | `22` | ssh port |
| `SSH_OPTS` | *(empty)* | extra ssh/scp flags, e.g. `-i ~/.ssh/deploy` |
| `REMOTE_DIR` | `~/document_repo` | project dir on the remote |
| `REMOTE_ENV_FORCE` | *(empty)* | `1` re-uploads `docker-compose.env` |

**First deploy:**

```bash
make remote-deploy REMOTE=user@host
make remote-admin REMOTE=user@host    # create the login on the remote
```

`remote-deploy` = `remote-init` + `remote-up`. `remote-init` alone installs the
bundle without starting anything.

**Every local target has a remote twin:**

| Local | Remote |
|-------|--------|
| `make init` | `remote-init` — create `REMOTE_DIR`, data dirs, upload bundle |
| `make up` / `down` / `restart` | `remote-up` / `remote-down` / `remote-restart` |
| `make status` | `remote-status` |
| `make logs` / `logs-web` | `remote-logs` / `remote-logs-web` |
| `make admin` / `shell` | `remote-admin` / `remote-shell` |
| `make consume FILE=...` | `remote-consume FILE=...` — scp into the remote consume dir |
| `make backup` | `remote-backup` — dump remotely, copy into local `backups/` |
| `make pull` | `remote-pull` |

The compose arguments are identical on both sides, so behavior matches.

**Sync rules:**

- `docker-compose.yml` is uploaded on every `remote-init`/`remote-deploy`.
- `docker-compose.env` is uploaded only when missing — overwriting it would
  change `POSTGRES_PASSWORD` on an initialized database and lock the stack out.
  Use `REMOTE_ENV_FORCE=1` when you really mean it.
- `data/` and `backups/` are created on the remote, never uploaded. Documents
  and the database stay there; `remote-down` keeps them.

**Upgrades:**

```bash
make remote-backup REMOTE=user@host
make remote-pull REMOTE=user@host
make remote-up REMOTE=user@host
```

**Restore** follows section 5 on the remote, with `REMOTE_DIR` as the project
root. `remote-backup` output is a normal backup directory, usable by either
machine.

## 8. Notes

- **Timezone** is `UTC` (`TZ` in `docker-compose.env`).
- **AI features** are intentionally disabled. To enable later, add an LLM
  service (e.g. Ollama) and uncomment the `PAPERLESS_AI_*` block in
  `docker-compose.yml`.
- **Ports**: only the web UI (`8000`) is exposed to the host; `db`, `broker`,
  `gotenberg`, and `tika` are internal to the Compose network.
