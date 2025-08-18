#!/bin/bash
set -uo pipefail

# ====== CONFIG ======
CERT_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqaggtx3yt3g3zkogvafeqmfneoufymbkymkaicp65lhqsa"
KEY_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqahl3rucnxgfxjd5b5ldjb7zpov3ir42wxpfkcjvtmlo2a"
SECRETS_DIR="/etc/ssl/cloudflare"
IMAGE_NAME="zkeulr/duelgood"
WEB_CONTAINER_NAME="duelgood-web"
DOMAIN_NAME="duelgood.org"

# ====== INSTALL OCI CLI ======
sudo dnf -y update
sudo dnf -y install oraclelinux-developer-release-el9
sudo dnf -y install python39-oci-cli

# ====== CREATE SECRETS DIR ======
sudo mkdir -p "$SECRETS_DIR"
sudo chown root:root "$SECRETS_DIR"
sudo chmod 700 "$SECRETS_DIR"

# ====== SET SSH TIMEOUT TO 24 HOURS ======
sudo sed -i '/^ClientAliveInterval/d' /etc/ssh/sshd_config || true
sudo sed -i '/^ClientAliveCountMax/d' /etc/ssh/sshd_config || true
echo "ClientAliveInterval 3600" | sudo tee -a /etc/ssh/sshd_config
echo "ClientAliveCountMax 24" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd || true

# ====== FETCH CERT & KEY FROM OCI VAULT ======
if ! oci --auth instance_principal secrets secret-bundle get \
    --secret-id "$CERT_SECRET_OCID" \
    --query "data.\"secret-bundle-content\".content" \
    --raw-output | base64 --decode | sudo tee "$SECRETS_DIR/cert.pem" > /dev/null; then
    echo "ERROR: Failed to fetch the certificate from OCI Vault." >&2
fi

if ! oci --auth instance_principal secrets secret-bundle get \
    --secret-id "$KEY_SECRET_OCID" \
    --query "data.\"secret-bundle-content\".content" \
    --raw-output | base64 --decode | sudo tee "$SECRETS_DIR/key.pem" > /dev/null; then
    echo "ERROR: Failed to fetch the key from OCI Vault." >&2
fi

sudo chmod 644 "$SECRETS_DIR/cert.pem" 
sudo chmod 600 "$SECRETS_DIR/key.pem" 

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
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=smtp
sudo firewall-cmd --reload || true

# ====== REMOVE OLD CONTAINERS ======
if sudo docker ps -a --format '{{.Names}}' | grep -q "^$WEB_CONTAINER_NAME$"; then
    echo "Removing old web container: $WEB_CONTAINER_NAME"
    sudo docker rm -f "$WEB_CONTAINER_NAME"
fi
if sudo docker ps -a --format '{{.Names}}' | grep -q "^$MAIL_CONTAINER_NAME$"; then
    echo "Removing old mail container: $MAIL_CONTAINER_NAME"
    sudo docker rm -f "$MAIL_CONTAINER_NAME"
fi

# ====== PULL LATEST IMAGE ======
sudo docker pull "$IMAGE_NAME"

# ====== RUN CONTAINERS ======
sudo docker run -d \
    --name "$WEB_CONTAINER_NAME" \
    --restart unless-stopped \
    -p 80:80 \
    -p 443:443 \
    -v "$SECRETS_DIR":"$SECRETS_DIR":ro \
    "$IMAGE_NAME"

