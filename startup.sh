#!/bin/bash
set -uo pipefail

# ====== CONFIG ======
CERT_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqaggtx3yt3g3zkogvafeqmfneoufymbkymkaicp65lhqsa"
KEY_SECRET_OCID="ocid1.vaultsecret.oc1.iad.amaaaaaaah7zwoqahl3rucnxgfxjd5b5ldjb7zpov3ir42wxpfkcjvtmlo2a"
SECRETS_DIR="/etc/ssl/cloudflare"

install_prereqs() {
  sudo dnf -y update
  sudo dnf -y install oraclelinux-developer-release-el9 || true
  command -v oci >/dev/null || sudo dnf -y install python39-oci-cli
  command -v docker >/dev/null || {
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
  }
}

fetch_certs() {
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

deploy_stack() {
  sudo docker-compose pull
  sudo docker-compose up -d
  sudo docker-compose run --rm backend flask --app app:create_app db-init
}

install_prereqs
fetch_certs
deploy_stack

echo ">>> All services deployed via docker-compose."