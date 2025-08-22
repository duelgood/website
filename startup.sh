#!/bin/bash
set -uo pipefail

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
  sudo docker stop $(sudo docker ps -a -q) 2>/dev/null || true
  sudo docker rm -f $(sudo docker ps -a -q) 2>/dev/null || true
  sudo docker volume prune -f
  sudo docker compose pull
  sudo docker compose up -d

  if ! sudo docker compose exec backend [ -d "/app/migrations" ]; then
    sudo docker compose exec backend flask db init
  fi
  sudo docker compose exec backend flask db migrate -m "auto migration" || true
  sudo docker compose exec backend flask db upgrade
}

# MAIN 
install_prereqs
configure_firewall
deploy_stack