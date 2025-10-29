#!/bin/bash
set -e  # Exit on error
set -x  # Enable tracing (prints each command before execution)

echo "Starting entrypoint script..."

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
# runuser is necessary to fix an issue 
# where opendkim would find the opendkim 
# user unavilable
if runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf & 2>&1; then
    echo "OpenDKIM started successfully."
else
    echo "Failed to start OpenDKIM." >&2
    exit 1
fi

echo "Starting Postfix in foreground..."
exec /usr/sbin/postfix start-fg