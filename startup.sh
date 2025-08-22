#!/bin/bash
set -uo pipefail

DEPLOY_DIR="/opt/duelgood"   # Path where docker-compose.yml lives

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

    # Stop & remove any existing containers (force)
    sudo docker compose down --volumes --remove-orphans || true
    sudo docker rm -f duelgood-db duelgood-backend duelgood-web 2>/dev/null || true

    # Pull latest images
    sudo docker compose pull

    # Start containers
    sudo docker compose up -d

    # wait for backend service to be running (timeout ~60s)
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

    # use -T for non-interactive exec in scripts
    sudo docker compose -p duelgood -f /opt/duelgood/docker-compose.yml exec -T backend sh -c "flask db init 2>/dev/null || true; flask db migrate --no-input || true; flask db upgrade --no-input || true"
}

# MAIN
install_prereqs
configure_firewall
deploy_stack