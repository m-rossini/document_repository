# Paperless-ngx management CLI.
# Run `make` or `make help` for the target list.
#
# Two target sets, same semantics:
#   make <target>            run on this machine
#   make remote-<target>     run the equivalent compose command on REMOTE
#
# Remote deployment never clones or builds on the remote. The bundle is
# validated locally, shipped over SSH, and started there with remote Docker.

SHELL := /bin/bash

COMPOSE_ARGS = docker compose --env-file docker-compose.env -f docker-compose.yml
COMPOSE = $(COMPOSE_ARGS)

RUNTIME_DIRS := data/db data/redisdata data/data data/media data/export data/consume
CONSUME_DIR := data/consume
BACKUP_ROOT := backups

# --- Remote settings (override on the command line or export in the shell) ---
#   make remote-up REMOTE=user@host
#   export REMOTE=user@host
REMOTE ?=
REMOTE_DIR ?= ~/document_repo
SSH_PORT ?= 22
SSH_OPTS ?=

SSH = ssh -p $(SSH_PORT)$(if $(SSH_OPTS), $(SSH_OPTS)) $(REMOTE)
SSH_TTY = ssh -t -p $(SSH_PORT)$(if $(SSH_OPTS), $(SSH_OPTS)) $(REMOTE)
SCP = scp -P $(SSH_PORT)$(if $(SSH_OPTS), $(SSH_OPTS))
COMPOSE_REMOTE = $(SSH) 'cd $(REMOTE_DIR) && $(COMPOSE_ARGS)'
COMPOSE_REMOTE_TTY = $(SSH_TTY) 'cd $(REMOTE_DIR) && $(COMPOSE_ARGS)'
REMOTE_CONSUME = $(REMOTE_DIR)/$(CONSUME_DIR)
REMOTE_RUNTIME_DIRS = $(addprefix $(REMOTE_DIR)/,$(RUNTIME_DIRS) $(BACKUP_ROOT))

.DEFAULT_GOAL := help

.PHONY: help init up down restart status logs logs-web admin consume backup pull shell \
        remote-guard remote-init remote-deploy remote-up remote-down remote-restart \
        remote-status remote-logs remote-logs-web remote-admin remote-consume \
        remote-backup remote-pull remote-shell

help: ## Show this help
	@echo "Local:"
	@grep -hE '^[a-z][a-z-]*:.*?## ' $(MAKEFILE_LIST) | grep -vE '^remote-' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Remote (REMOTE=user@host, optional SSH_PORT=<port> REMOTE_DIR=<path>):"
	@grep -hE '^remote-[a-z-]*:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# --- Local -------------------------------------------------------------------

init: ## Create data dirs and docker-compose.env from the template
	@mkdir -p $(RUNTIME_DIRS) $(BACKUP_ROOT)
	@if [ ! -f docker-compose.env ]; then \
		cp docker-compose.env.example docker-compose.env; \
		echo "Created docker-compose.env — edit PAPERLESS_SECRET_KEY and POSTGRES_PASSWORD before 'make up'."; \
	else \
		echo "docker-compose.env already exists, leaving it untouched."; \
	fi

up: ## Start the stack (detached)
	$(COMPOSE) up -d

down: ## Stop and remove containers (data volumes on disk are kept)
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

status: ## Show service status
	$(COMPOSE) ps

logs: ## Tail logs from all services
	$(COMPOSE) logs -f --tail=100

logs-web: ## Tail only the webserver logs
	$(COMPOSE) logs -f --tail=100 webserver

admin: ## Create a superuser (interactive)
	$(COMPOSE) exec webserver python3 manage.py createsuperuser

consume: ## Copy a file into the consume dir: make consume FILE=/path/to/doc.pdf
	@if [ -z "$(FILE)" ]; then echo "Usage: make consume FILE=/path/to/document.pdf"; exit 1; fi
	@test -f "$(FILE)" || { echo "No such file: $(FILE)"; exit 1; }
	cp "$(FILE)" $(CONSUME_DIR)/
	@echo "Queued $(notdir $(FILE)) for import."

backup: ## Dump DB + media into backups/YYYYMMDD-HHMM/
	@stamp=$$(date +%Y%m%d-%H%M); dest=$(BACKUP_ROOT)/$$stamp; \
	mkdir -p "$$dest"; \
	echo "Backing up to $$dest ..."; \
	$(COMPOSE) exec -T db pg_dump -U $${POSTGRES_USER:-paperless} $${POSTGRES_DB:-paperless} > "$$dest/db.sql"; \
	tar -czf "$$dest/media.tar.gz" -C data media; \
	echo "Done: $$dest"

pull: ## Pull the newest images (then 'make up' to apply)
	$(COMPOSE) pull

shell: ## Open a shell inside the webserver container
	$(COMPOSE) exec webserver bash

# --- Remote ------------------------------------------------------------------

remote-guard:
	@if [ -z "$(REMOTE)" ]; then \
		echo "REMOTE is not set. Usage: make <target> REMOTE=user@host"; \
		exit 1; \
	fi

remote-init: remote-guard ## Install/refresh the remote bundle (compose file, env, data dirs)
	@test -f docker-compose.env || { \
		echo "docker-compose.env missing — run 'make init' and edit it first."; exit 1; }
	@echo "Validating the bundle locally ..."
	@$(COMPOSE) config -q
	@$(SSH) 'docker compose version >/dev/null 2>&1' || { \
		echo "Remote host needs Docker Engine with the Compose v2 plugin."; exit 1; }
	@echo "Preparing $(REMOTE):$(REMOTE_DIR) ..."
	@$(SSH) "mkdir -p $(REMOTE_RUNTIME_DIRS)"
	@$(SCP) docker-compose.yml "$(REMOTE):$(REMOTE_DIR)/"
	@if [ -n "$(REMOTE_ENV_FORCE)" ]; then \
		echo "REMOTE_ENV_FORCE set — overwriting docker-compose.env."; \
		$(SCP) docker-compose.env "$(REMOTE):$(REMOTE_DIR)/"; \
	elif $(SSH) "test -f $(REMOTE_DIR)/docker-compose.env"; then \
		echo "Remote docker-compose.env kept (REMOTE_ENV_FORCE=1 to overwrite)."; \
	else \
		echo "Uploading docker-compose.env."; \
		$(SCP) docker-compose.env "$(REMOTE):$(REMOTE_DIR)/"; \
	fi
	@echo "Remote bundle ready: $(REMOTE):$(REMOTE_DIR)"

remote-deploy: remote-init remote-up ## Install the bundle and start the stack on REMOTE

remote-up: remote-guard ## Start the stack on REMOTE
	$(COMPOSE_REMOTE) up -d

remote-down: remote-guard ## Stop the remote stack (data on disk is kept)
	$(COMPOSE_REMOTE) down

remote-restart: remote-guard ## Restart the remote services
	$(COMPOSE_REMOTE) restart

remote-status: remote-guard ## Show remote service status
	$(COMPOSE_REMOTE) ps

remote-logs: remote-guard ## Tail remote logs from all services
	$(COMPOSE_REMOTE_TTY) logs -f --tail=100

remote-logs-web: remote-guard ## Tail only the remote webserver logs
	$(COMPOSE_REMOTE_TTY) logs -f --tail=100 webserver

remote-admin: remote-guard ## Create a superuser on REMOTE (interactive)
	$(COMPOSE_REMOTE_TTY) exec webserver python3 manage.py createsuperuser

remote-consume: remote-guard ## Copy a file into the remote consume dir: FILE=/path/to/doc.pdf
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make remote-consume REMOTE=user@host FILE=/path/to/document.pdf"; exit 1; \
	fi
	@test -f "$(FILE)" || { echo "No such file: $(FILE)"; exit 1; }
	@$(SCP) "$(FILE)" "$(REMOTE):$(REMOTE_CONSUME)/"
	@echo "Queued $(notdir $(FILE)) for import on $(REMOTE)."

remote-backup: remote-guard ## Dump the remote DB + media, then copy it into local backups/
	@stamp=$$(date +%Y%m%d-%H%M); \
	echo "Backing up $(REMOTE) into $(BACKUP_ROOT)/$$stamp ..."; \
	$(SSH) "cd $(REMOTE_DIR) && mkdir -p $(BACKUP_ROOT)/$$stamp" || exit 1; \
	$(SSH) "cd $(REMOTE_DIR) && $(COMPOSE_ARGS) exec -T db pg_dump -U \$${POSTGRES_USER:-paperless} \$${POSTGRES_DB:-paperless} > $(BACKUP_ROOT)/$$stamp/db.sql" || exit 1; \
	$(SSH) "cd $(REMOTE_DIR) && tar -czf $(BACKUP_ROOT)/$$stamp/media.tar.gz -C data media" || exit 1; \
	mkdir -p $(BACKUP_ROOT); \
	$(SCP) -r "$(REMOTE):$(REMOTE_DIR)/$(BACKUP_ROOT)/$$stamp" "$(BACKUP_ROOT)/"; \
	echo "Done: $(BACKUP_ROOT)/$$stamp"

remote-pull: remote-guard ## Pull the newest images on REMOTE (then 'make remote-up')
	$(COMPOSE_REMOTE) pull

remote-shell: remote-guard ## Open a shell inside the remote webserver container
	$(COMPOSE_REMOTE_TTY) exec webserver bash
