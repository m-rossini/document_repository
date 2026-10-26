# AGENTS.md

Canonical agent instructions for this repository. **Read this file in full before
doing any work.** `CLAUDE.md` is a one-line pointer to this file.

Applies to every agent that works here: Claude Code, Codex, opencode, Cursor, and
anything else.

---

## 1. MANDATORY: use skills

**Using skills is mandatory, not optional.** Before you plan, search, edit, or run
commands, you **MUST** find the skills that apply to the task and follow them.
Skills are the single source of truth for "how we do things" here — writing style,
PDF/Word/Excel/PowerPoint handling, research workflow, browser and desktop control,
proposal writing, and more. Skipping an applicable skill is a failed task.

### 1.1 The one place skills live

There is exactly **one** skills location per scope. Never copy skills into
tool-specific folders — link to these instead.

| Scope | Path | Who reads it |
|-------|------|--------------|
| User machine | `~/.claude/skills/` | Claude Code (native), opencode (native + config), Codex (symlinked) |
| This project | `.claude/skills/` | Claude Code (native); opencode via the `.opencode/skill` symlink; Codex via this file |

User skills appear in two layouts:

```
~/.claude/skills/<name>/SKILL.md
~/.claude/skills/synced/<bucket>/<name>/SKILL.md
```

Every skill is a directory containing a `SKILL.md` with YAML frontmatter
(`name`, `description`). A skill may ship extra files (scripts, references,
templates) next to `SKILL.md` — read those when the skill tells you to.

### 1.2 Required procedure

1. **Discover** the skills:

   ```bash
   ls -1 ~/.claude/skills 2>/dev/null
   ls -1 ~/.claude/skills/synced/*/ 2>/dev/null
   ls -1 .claude/skills 2>/dev/null
   ```

2. **Match** the task to skills by reading each `SKILL.md`'s `description`. A skill
   applies when its description matches the task, the file type involved, or a
   keyword the user used.
3. **Load** the full `SKILL.md` of every matching skill (plus any file it points to)
   **before** you act.
4. **Follow** it. On conflict, the project skill (`.claude/skills`) wins over a user
   skill, and the more specific skill wins over the general one.
5. **Say so.** When you use a skill, name the skill(s) you loaded.

If you are unsure whether a skill applies, load it and check. Loading is cheap;
skipping an applicable skill is expensive.

### 1.3 How each tool reaches the one place

- **Claude Code** — reads `~/.claude/skills/` and the project's `.claude/skills/`
  natively.
- **opencode** — auto-loads `~/.claude/skills/<name>/SKILL.md`; the nested `synced/`
  set is registered in `~/.config/opencode/opencode.jsonc` under `skills.paths`;
  project skills reach it through the `.opencode/skill → ../.claude/skills` symlink.
- **Codex** — reads `~/.codex/skills/`, where each skill is a symlink back into
  `~/.claude/skills/...`; it reads this `AGENTS.md` for the policy.

---

## 2. Project overview

Self-hosted **Paperless-ngx** document management system.

- **Stack** (`docker-compose.yml`): `webserver` (Paperless-ngx, UI on port 8000),
  `db` (PostgreSQL 16), `broker` (Redis 7), `gotenberg` (Office→PDF), `tika`
  (extra text extraction).
- **State** lives under `./data/` (bind mounts, gitignored).
- **Config** lives in `docker-compose.env` (gitignored; created from
  `docker-compose.env.example` by `make init`).
- **CLI**: everything is driven through the `Makefile` (`make help`).
- **Docs**: `README.md` (quickstart), `OPERATIONS.md` (start/stop, ingest,
  backup/restore, upgrades).
- OCR languages: `por+eng` (the `por` pack is installed at container start via
  `PAPERLESS_OCR_LANGUAGES`).

## 3. Commands

Use `make` targets instead of raw `docker compose` where one exists:

| Target | Purpose |
|--------|---------|
| `make init` | Create `./data/*` dirs and `docker-compose.env` from the template |
| `make up` / `make down` / `make restart` | Lifecycle (data is preserved on `down`) |
| `make status` | Service health |
| `make logs` / `make logs-web` | Follow logs |
| `make admin` | Create the Paperless superuser (interactive) |
| `make consume FILE=...` | Queue a file for import |
| `make backup` | DB dump + media archive into `backups/` |
| `make shell` | Shell inside the webserver container |
| `make pull` | Pull the newest images |
| `make remote-deploy REMOTE=user@host` | Validate locally, upload the bundle, start the stack on the remote |
| `make remote-<target>` | Remote twin of every target above (`REMOTE`, `SSH_PORT`, `SSH_OPTS`, `REMOTE_DIR`) |

`make help` lists the two groups. Local and remote targets share `COMPOSE_ARGS`,
so their behavior stays identical; `remote-` only swaps the execution prefix
(`ssh … 'cd $REMOTE_DIR && …'`).

## 4. Guardrails

- **Never commit** `data/`, `backups/`, or `docker-compose.env` — they are
  gitignored runtime state and secrets. Do not `git add -f` them.
- **Never** put real secrets in `docker-compose.env.example` or any tracked file.
- After changing `docker-compose.env`, `docker-compose.yml`, or any config-time
  file, tell the user to restart the affected process (containers for the stack;
  quit/relaunch opencode for opencode config).
- **Never build or clone on the remote.** Remote deployment ships only
  `docker-compose.yml` and `docker-compose.env`; images come from registries.
  The bundle is validated locally (`docker compose config -q`) before upload.
- **Keep local and remote targets in sync.** Add the `remote-` twin for every new
  operational target and reuse `COMPOSE_ARGS` — do not restate compose flags.
- **Never overwrite the remote `docker-compose.env` implicitly** — it carries
  `POSTGRES_PASSWORD`, and changing it after database init breaks the connection.
  Only `REMOTE_ENV_FORCE=1` may overwrite it.
- Prefer editing existing files over creating new ones; keep the `Makefile` as the
  single entry point for operations.
