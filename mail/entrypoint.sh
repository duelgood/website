#!/bin/bash
set -e

echo "Starting entrypoint script..."

# Setup DKIM key
DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

echo "Setting up DKIM key..."
mkdir -p "$(dirname "$DKIM_KEY_PATH")"
cp "$SECRET_PATH" "$DKIM_KEY_PATH"
chown opendkim:opendkim "$DKIM_KEY_PATH"
chmod 600 "$DKIM_KEY_PATH"

# Ensure OpenDKIM directory exists
mkdir -p /var/spool/postfix/opendkim
chown opendkim:postfix /var/spool/postfix/opendkim
chmod 750 /var/spool/postfix/opendkim

echo "Starting OpenDKIM..."
runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf &

# Wait for OpenDKIM socket
sleep 2
if [ ! -S /var/spool/postfix/opendkim/opendkim.sock ]; then
    echo "OpenDKIM socket not found. Check OpenDKIM config/logs." >&2
    exit 1
fi

echo "Starting Postfix..."
exec postfix start-fg