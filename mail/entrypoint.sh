#!/bin/bash
set -e  # Exit on error
set -x  # Enable tracing (prints each command before execution)

echo "Starting entrypoint script..."

service rsyslog start

DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

echo "Setting up DKIM key..."
mkdir -p "$(dirname "$DKIM_KEY_PATH")"
cp "$SECRET_PATH" "$DKIM_KEY_PATH"
chown opendkim:opendkim "$DKIM_KEY_PATH"
chmod 600 "$DKIM_KEY_PATH"
echo "DKIM key setup complete."

echo "Setting up Postfix OpenDKIM directory..."
mkdir -p /var/spool/postfix/opendkim
chown opendkim:postfix /var/spool/postfix/opendkim
chmod 750 /var/spool/postfix/opendkim
echo "Postfix OpenDKIM directory setup complete."

echo "Initializing Postfix..."
# Removed redirection to show output; errors will be visible
service postfix start || true
postfix stop 2>&1 || true
echo "Postfix initialization complete."

echo "Starting OpenDKIM as opendkim user..."
runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf &
OPENDKIM_PID=$!
sleep 2  # Give it time to start/fail
if kill -0 $OPENDKIM_PID 2>/dev/null; then
    echo "OpenDKIM started successfully (PID: $OPENDKIM_PID)."
else
    echo "Failed to start OpenDKIM." >&2
    exit 1
fi

if [ -S /var/spool/postfix/opendkim/opendkim.sock ]; then
    echo "OpenDKIM socket created successfully."
else
    echo "OpenDKIM socket not found. Check OpenDKIM config/logs." >&2
    exit 1
fi

echo "Checking Postfix config..."
postfix check
service postfix start

while true; do sleep 30; done