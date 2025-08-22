#!/bin/bash
set -uo pipefail

DEPLOY_DIR="/opt/duelgood"   # Path where docker-compose.yml lives

# Postgres credentials
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"
POSTGRES_DB="duelgood"

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

wait_for_db() {
    echo "Waiting for DB to be ready..."
    until sudo docker compose exec -T backend python - <<'EOF' 2>/dev/null
import sys, psycopg2, os
try:
    conn = psycopg2.connect(
        dbname=os.getenv("POSTGRES_DB", "duelgood"),
        user=os.getenv("POSTGRES_USER", "postgres"),
        password=os.getenv("POSTGRES_PASSWORD", "postgres"),
        host=os.getenv("DB_HOST", "db"),
        port=5432
    )
    conn.close()
except Exception:
    sys.exit(1)
EOF
    do
        echo -n "."
        sleep 2
    done
    echo "DB is ready!"
}

deploy_stack() {
    cd "$DEPLOY_DIR" || exit 1

    # Set environment variables for docker-compose
    export POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB

    # Pull latest images (idempotent)
    sudo docker compose pull

    # Start or update containers without forcing removal
    sudo docker compose up -d

    # Wait until DB is ready
    wait_for_db

    # Run migrations inside backend container
    sudo docker compose exec backend bash -c "
        set -e
        if [ ! -d /app/migrations ]; then
            flask db init
        fi
        flask db migrate -m 'auto migration' || true
        flask db upgrade
    "
}

# MAIN
install_prereqs
configure_firewall
deploy_stack