# Detect Package Manager
PKG_MANAGER := $(shell which dnf 2>/dev/null || which apt-get 2>/dev/null)

# Detect Container Runtime
DOCKER_BIN := $(shell which podman 2>/dev/null || which docker 2>/dev/null)

# Determine Compose Command
COMPOSE_CMD := $(shell if [ -f /usr/libexec/docker/cli-plugins/docker-compose ]; then echo "$(DOCKER_BIN) compose"; else echo "$(DOCKER_BIN)-compose"; fi)

.PHONY: setup start install-timer backup

setup:
	@echo "Updating packages and installing dependencies..."
	@if [ "$(PKG_MANAGER)" = "/usr/bin/dnf" ]; then \
		sudo dnf update -y && sudo dnf install -y curl unzip podman podman-compose; \
	elif [ "$(PKG_MANAGER)" = "/usr/bin/apt-get" ]; then \
		sudo apt-get update && sudo apt-get install -y curl unzip docker.io docker-compose; \
	fi
	@echo "Installing Rclone..."
	@if ! command -v rclone &> /dev/null; then \
		curl https://rclone.org/install.sh | sudo bash; \
	else \
		echo "Rclone is already installed, skipping..."; \
	fi
	@echo "Provisioning local folders..."
	@mkdir -p data media export consume systemd
	@grep -q "PAPERLESS_ADMIN_PASSWORD" .env 2>/dev/null || ( \
		PASSWORD=$$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16); \
		echo "PAPERLESS_ADMIN_USER=admin" >> .env; \
		echo "PAPERLESS_ADMIN_PASSWORD=$$PASSWORD" >> .env; \
		echo "PAPERLESS_PORT=8000" >> .env; \
		echo "Generated .env with default admin credentials:"; \
		echo "User: admin"; \
		echo "Pass: $$PASSWORD"; \
		echo "Port: 8000" \
	)
	@$(MAKE) install-timer

start:
	$(COMPOSE_CMD) up -d

install-timer:
	@mkdir -p ~/.config/systemd/user/
	@cp systemd/paperless-backup.service ~/.config/systemd/user/
	@cp systemd/paperless-backup.timer ~/.config/systemd/user/
	@sed -i "s|{{PROJECT_ROOT}}|$$PWD|g" ~/.config/systemd/user/paperless-backup.service
	@systemctl --user daemon-reload
	@systemctl --user enable --now paperless-backup.timer
	@echo "Systemd timer activated."

backup:
	./backup.sh
