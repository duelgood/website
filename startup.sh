#!/bin/bash
set -uo pipefail

# Path where compose.yml will live
DEPLOY_DIR="/opt/duelgood"

deploy_stack() {
    cd "$DEPLOY_DIR" || exit 1

    if ! podman login --get-login ghcr.io >/dev/null 2>&1; then
        # login to podman with 
        podman login -p=$GITHUB_GHCR_PAT
    fi

    if podman secret exists "stripe_secret_key" >/dev/null 2>&1; then
        podman secret rm "stripe_secret_key"
    fi

    if podman secret exists "stripe_webhook_secret" >/dev/null 2>&1; then
        podman secret rm "stripe_webhook_secret"
    fi

    echo -n "$STRIPE_SECRET_KEY" | podman secret create stripe_secret_key -
    echo -n "$STRIPE_WEBHOOK_SECRET" | podman secret create stripe_webhook_secret -
    
    # Stop & remove any existing containers (force)
    podman-compose down --volumes --remove-orphans || true
    podman rm -f duelgood-db duelgood-backend duelgood-web 2>/dev/null || true
    
    # Pull latest images
    podman-compose -p duelgood pull
    
    # Start containers
    podman-compose -p duelgood up -d
    
    # Wait for backend service to be running (timeout ~60s).
    # This is required to solve an issue with the backend
    for i in $(seq 1 30); do
        cid=$(podman-compose -p duelgood -f /opt/duelgood/compose.yml ps -q backend 2>/dev/null || true)
        if [ -n "$cid" ]; then
            state=$(podman inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
            if [ "$state" = "running" ]; then
                echo "backend is running"
                break
            fi
        fi
        echo "waiting for backend to start... ($i)"
        sleep 2
    done
    
    podman-compose -p duelgood -f /opt/duelgood/compose.yml exec -T backend sh -c "flask db init 2>/dev/null || true; flask db migrate || true; flask db upgrade || true"
}

# MAIN
deploy_stack