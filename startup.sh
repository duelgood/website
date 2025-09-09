#!/bin/bash
set -uo pipefail

# Path where docker-compose.yml will live
DEPLOY_DIR="/opt/duelgood"

install_prereqs() {
    if ! command -v podman >/dev/null; then
        sudo pacman -Syu 
        sudo pacman -Sy --noconfirm podman podman-compose
        # Enable podman socket for compose compatibility
        systemctl --user enable --now podman.socket
        # Create systemd user directory if it doesn't exist
        mkdir -p ~/.config/systemd/user
        # Enable lingering to allow user services to run without login
        sudo loginctl enable-linger $USER
    fi
}

deploy_stack() {
    cd "$DEPLOY_DIR" || exit 1
    
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
        cid=$(podman-compose -p duelgood -f /opt/duelgood/docker-compose.yml ps -q backend 2>/dev/null || true)
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
    
    podman-compose -p duelgood -f /opt/duelgood/docker-compose.yml exec -T backend sh -c "flask db init 2>/dev/null || true; flask db migrate || true; flask db upgrade || true"
}

# MAIN
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
install_prereqs
deploy_stack