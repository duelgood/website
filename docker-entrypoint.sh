#!/bin/sh
# Generate self-signed cert if it doesn't exist
if [ ! -f /etc/ssl/private/selfsigned.key ]; then
    echo "Generating self-signed certificate..."
    mkdir -p /etc/ssl/private /etc/ssl/certs
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/selfsigned.key \
        -out /etc/ssl/certs/selfsigned.crt \
        -subj "/CN=duelgood.org"
fi

echo "Starting nginx..."
exec nginx -g "daemon off;"
