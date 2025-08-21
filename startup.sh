#!/bin/bash
set -uo pipefail

# CONFIG 
CERT_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqaggtx3yt3g3zkogvafeqmfneoufymbkymkaicp65lhqsa"
KEY_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqahl3rucnxgfxjd5b5ldjb7zpov3ir42wxpfkcjvtmlo2a"
SECRETS_DIR="/etc/ssl/cloudflare"

# FUNCTIONS 

install_prereqs() {
  echo ">>> Installing prerequisites..."
  sudo dnf -y update
  sudo dnf -y install oraclelinux-developer-release-el9 || true

  if ! command -v oci >/dev/null; then
    sudo dnf -y install python39-oci-cli
  fi

  if ! command -v docker >/dev/null; then
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
  else
    echo "Docker already installed, skipping."
  fi
}

configure_ssh_agent() {
  echo ">>> Configuring SSH agent..."
  
  # Check if SSH agent config already exists in .bash_profile
  if ! grep -q "SSH_ENV=" ~/.bash_profile 2>/dev/null; then
    echo "Adding SSH agent configuration to .bash_profile..."
    cat >> ~/.bash_profile << 'EOF'

SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"$SSH_ENV"
    echo succeeded
    chmod 600 "$SSH_ENV"
    . "$SSH_ENV" >/dev/null
    /usr/bin/ssh-add;
}

# Source SSH settings, if applicable

if [ -f "$SSH_ENV" ]; then
    . "$SSH_ENV" >/dev/null
    #ps $SSH_AGENT_PID doesn't work under Cygwin
    ps -ef | grep $SSH_AGENT_PID | grep ssh-agent$ >/dev/null || {
        start_agent
    }
else
    start_agent
fi
EOF
  else
    echo "SSH agent configuration already exists in .bash_profile, skipping."
  fi

  # Start SSH agent if not already running
  SSH_ENV="$HOME/.ssh/agent-environment"
  if [ -f "$SSH_ENV" ]; then
    . "$SSH_ENV" >/dev/null
    ps -ef | grep $SSH_AGENT_PID | grep ssh-agent$ >/dev/null || {
      echo "Starting SSH agent..."
      /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"$SSH_ENV"
      chmod 600 "$SSH_ENV"
      . "$SSH_ENV" >/dev/null
      /usr/bin/ssh-add
    }
  else
    echo "Starting SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"$SSH_ENV"
    chmod 600 "$SSH_ENV"
    . "$SSH_ENV" >/dev/null
    /usr/bin/ssh-add
  fi
}

fetch_certs() {
  echo ">>> Fetching TLS certs from OCI Vault..."
  sudo mkdir -p "$SECRETS_DIR" && sudo chmod 700 "$SECRETS_DIR"

  oci --auth instance_principal secrets secret-bundle get \
    --secret-id "$CERT_SECRET_OCID" \
    --query "data.\"secret-bundle-content\".content" \
    --raw-output | base64 --decode | sudo tee "$SECRETS_DIR/cert.pem" >/dev/null

  oci --auth instance_principal secrets secret-bundle get \
    --secret-id "$KEY_SECRET_OCID" \
    --query "data.\"secret-bundle-content\".content" \
    --raw-output | base64 --decode | sudo tee "$SECRETS_DIR/key.pem" >/dev/null

  sudo chmod 644 "$SECRETS_DIR/cert.pem"
  sudo chmod 600 "$SECRETS_DIR/key.pem"
}

configure_firewall() {
  echo ">>> Configuring firewall..."
  sudo firewall-cmd --permanent --add-service=http
  sudo firewall-cmd --permanent --add-service=https
  sudo firewall-cmd --reload || true
}

deploy_stack() {
  echo ">>> Deploying full stack via docker-compose..."
  sudo docker compose pull
  sudo docker compose up -d
  echo ">>> Initializing database..."
  sudo docker compose exec backend flask db-init
}

# MAIN 
install_prereqs
configure_ssh_agent
fetch_certs
configure_firewall
deploy_stack

echo ">>> Startup complete. All services are running in docker-compose."