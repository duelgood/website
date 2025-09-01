#!/bin/bash
set -uo pipefail

DEPLOY_DIR="/opt/duelgood"   # Path where docker-compose.yml will live

install_prereqs() {
    if ! command -v docker >/dev/null; then
        sudo pacman -Sy  --noconfirm docker docker-compose firewalld
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

    # Stop & remove any existing containers (force)
    sudo docker compose down --volumes --remove-orphans || true
    sudo docker rm -f duelgood-db duelgood-backend duelgood-web 2>/dev/null || true

    # Pull latest images
    sudo docker compose pull

    # Start containers
    sudo docker compose up -d

    # Wait for backend service to be running (timeout ~60s).
    # This is required to solve an issue with the backend
    for i in $(seq 1 30); do
      cid=$(sudo docker compose -p duelgood -f /opt/duelgood/docker-compose.yml ps -q backend 2>/dev/null || true)
      if [ -n "$cid" ]; then
        state=$(sudo docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
        if [ "$state" = "running" ]; then
          echo "backend is running"
          break
        fi
      fi
      echo "waiting for backend to start... ($i)"
      sleep 2
    done

    sudo docker compose -p duelgood -f /opt/duelgood/docker-compose.yml exec -T backend sh -c "flask db init 2>/dev/null || true; flask db migrate || true; flask db upgrade || true"
}

# MAIN
install_prereqs
configure_firewall
deploy_stack