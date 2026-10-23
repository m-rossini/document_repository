# Paperless-ngx management CLI.
# Run `make` or `make help` for the target list.

SHELL := /bin/bash
COMPOSE := docker compose --env-file docker-compose.env -f docker-compose.yml
CONSUME_DIR := data/consume
BACKUP_ROOT := backups

.DEFAULT_GOAL := help

.PHONY: help init up down restart status logs logs-web admin consume backup shell

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

init: ## Create data dirs and docker-compose.env from the template
	@mkdir -p data/db data/redisdata data/data data/media data/export data/consume $(BACKUP_ROOT)
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

shell: ## Open a shell inside the webserver container
	$(COMPOSE) exec webserver bash
