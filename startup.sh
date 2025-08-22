#!/bin/bash
set -uo pipefail

DEPLOY_DIR="/opt/duelgood" 

install_prereqs() {
    sudo dnf -y update

    if ! command -v docker >/dev/null; then
        sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl enable --now docker
        sudo usermod -aG docker $USER
    fi
}

configure_firewall() {
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload || true
}

deploy_stack() {
    cd "$DEPLOY_DIR" || exit 1

    # Stop & clean old containers
    sudo docker compose down --volumes --remove-orphans

    # Pull latest images
    sudo docker compose pull

    # Start containers
    sudo docker compose up -d

    # Ensure migrations exist inside the backend container
    if ! sudo docker compose exec backend test -d "/app/migrations"; then
        sudo docker compose exec backend flask db init
    fi

    # Auto-generate migrations (ignore if no changes)
    sudo docker compose exec backend bash -c "flask db migrate -m 'auto migration' || true"

    # Apply all migrations
    sudo docker compose exec backend flask db upgrade
}

# MAIN
install_prereqs
configure_firewall
deploy_stack