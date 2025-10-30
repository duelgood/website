#!/bin/bash
set -e

echo "Starting mail server..."

# Setup DKIM key
DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

if [ -f "$SECRET_PATH" ]; then
    echo "Setting up DKIM key..."
    mkdir -p "$(dirname "$DKIM_KEY_PATH")"
    cp "$SECRET_PATH" "$DKIM_KEY_PATH"
    chown opendkim:opendkim "$DKIM_KEY_PATH"
    chmod 600 "$DKIM_KEY_PATH"
    echo "DKIM key setup complete."
else
    echo "Warning: DKIM secret not found at $SECRET_PATH"
fi

# Ensure OpenDKIM directory exists
mkdir -p /var/spool/postfix/opendkim
chown opendkim:postfix /var/spool/postfix/opendkim
chmod 750 /var/spool/postfix/opendkim

echo "Starting OpenDKIM..."
runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf &

# Wait for OpenDKIM socket
echo "Waiting for OpenDKIM socket..."
for i in {1..10}; do
    if [ -S /var/spool/postfix/opendkim/opendkim.sock ]; then
        echo "OpenDKIM socket created successfully."
        break
    fi
    sleep 1
done

if [ ! -S /var/spool/postfix/opendkim/opendkim.sock ]; then
    echo "ERROR: OpenDKIM socket not found after 10 seconds" >&2
    exit 1
fi

echo "Starting Postfix..."
exec postfix start-fg