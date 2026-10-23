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
docker compose --env-file docker-compose.env pull
make up
```

Paperless runs migrations automatically on startup.

## 7. Notes

- **Timezone** is `UTC` (`TZ` in `docker-compose.env`).
- **AI features** are intentionally disabled. To enable later, add an LLM
  service (e.g. Ollama) and uncomment the `PAPERLESS_AI_*` block in
  `docker-compose.yml`.
- **Ports**: only the web UI (`8000`) is exposed to the host; `db`, `broker`,
  `gotenberg`, and `tika` are internal to the Compose network.
