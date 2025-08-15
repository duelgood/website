#!/bin/bash
set -uo pipefail

# ====== CONFIG ======
CERT_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqaggtx3yt3g3zkogvafeqmfneoufymbkymkaicp65lhqsa"
KEY_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqahl3rucnxgfxjd5b5ldjb7zpov3ir42wxpfkcjvtmlo2a"
SECRETS_DIR="/etc/ssl/cloudflare"
IMAGE_NAME="zkeulr/duelgood"
CONTAINER_NAME="duelgood-web"
DNS_PROVIDER="cloudflare"

# ====== SET SSH TIMEOUT TO 24 HOURS ======
sudo sed -i '/^ClientAliveInterval/d' /etc/ssh/sshd_config || true
sudo sed -i '/^ClientAliveCountMax/d' /etc/ssh/sshd_config || true
echo "ClientAliveInterval 3600" | sudo tee -a /etc/ssh/sshd_config
echo "ClientAliveCountMax 24" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd || true

# ====== INSTALL DOCKER & COMPOSE ======
if ! command -v docker &> /dev/null; then
    sudo yum install -y yum-utils || true
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true
    sudo systemctl enable --now docker || true
else
    echo "Docker already installed, skipping."
fi

# ====== ENABLE FIREWALL PORTS ======
sudo firewall-cmd --permanent --add-service=http || true
sudo firewall-cmd --permanent --add-service=https || true
sudo firewall-cmd --reload || true

# ====== RUN CONTAINER ======
if ! sudo docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    sudo docker rm -f $CONTAINER_NAME
fi

sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 80:80 \
    -p 443:443 \
    -v "$SECRETS_DIR":"$SECRETS_DIR":ro \
    "$IMAGE_NAME"