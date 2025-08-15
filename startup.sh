#!/bin/bash
set -euo pipefail

# ====== CONFIG ======
CERT_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqaggtx3yt3g3zkogvafeqmfneoufymbkymkaicp65lhqsa"
KEY_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqahl3rucnxgfxjd5b5ldjb7zpov3ir42wxpfkcjvtmlo2a"
SECRETS_DIR="/etc/ssl/cloudflare"
IMAGE_NAME="zkeulr/duelgood"
CONTAINER_NAME="duelgood-web"

# ====== INSTALL OCI CLI ======
sudo dnf -y update
sudo dnf -y install oraclelinux-developer-release-el9
sudo dnf -y install python39-oci-cli

# ====== CREATE SECRETS DIR ======
sudo mkdir -p "$SECRETS_DIR"
sudo chown root:root "$SECRETS_DIR"
sudo chmod 700 "$SECRETS_DIR"

# ====== SET SSH TIMEOUT TO 24 HOURS ======
echo "ClientAliveInterval 3600" | sudo tee -a /etc/ssh/sshd_config
echo "ClientAliveCountMax 24" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd

# ====== FETCH CERT & KEY FROM OCI VAULT ======
if ! oci --auth instance_principal secrets secret-bundle get \
    --secret-id "$CERT_SECRET_OCID" \
    --query "data.\"secret-bundle-content\".content" \
    --raw-output | base64 --decode | sudo tee "$SECRETS_DIR/cert.pem" > /dev/null; then
    echo "ERROR: Failed to fetch the certificate from OCI Vault." >&2
    echo "Please manually paste the certificate into $SECRETS_DIR/cert.pem" >&2
fi

if ! oci --auth instance_principal secrets secret-bundle get \
    --secret-id "$KEY_SECRET_OCID" \
    --query "data.\"secret-bundle-content\".content" \
    --raw-output | base64 --decode | sudo tee "$SECRETS_DIR/key.pem" > /dev/null; then
    echo "ERROR: Failed to fetch the key from OCI Vault." >&2
    echo "Please manually paste the key into $SECRETS_DIR/key.pem" >&2
fi

sudo chmod 644 "$SECRETS_DIR/cert.pem" || true
sudo chmod 600 "$SECRETS_DIR/key.pem" || true

# ====== INSTALL DOCKER & COMPOSE ======
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker

# ====== ENABLE FIREWALL PORTS ======
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
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