#!/bin/bash
set -uo pipefail

# FUNCTIONS 

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
  docker compose pull
  docker compose up -d
  docker compose exec backend flask db-init || true
}

# MAIN 
install_prereqs
configure_firewall
deploy_stack