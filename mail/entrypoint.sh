#!/bin/bash
set -e
set -x  # Keep tracing for debugging

echo "Starting entrypoint script..."

# Setup DKIM key
DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

echo "Checking for DKIM secret..."
if [ -f "$SECRET_PATH" ]; then
    echo "DKIM secret found, setting up..."
    mkdir -p "$(dirname "$DKIM_KEY_PATH")"
    cp "$SECRET_PATH" "$DKIM_KEY_PATH"
    chown opendkim:opendkim "$DKIM_KEY_PATH"
    chmod 600 "$DKIM_KEY_PATH"
    echo "DKIM key setup complete."
else
    echo "ERROR: DKIM secret not found at $SECRET_PATH"
    echo "Available in /run/secrets:"
    ls -la /run/secrets/ || echo "No secrets directory"
    exit 1
fi

echo "Setting up OpenDKIM directory..."
mkdir -p /var/spool/postfix/opendkim
chown opendkim:postfix /var/spool/postfix/opendkim
chmod 750 /var/spool/postfix/opendkim
echo "OpenDKIM directory setup complete."

echo "Starting OpenDKIM..."
# Start OpenDKIM in background
runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf &
OPENDKIM_PID=$!

echo "Waiting for OpenDKIM socket..."
# Wait for socket with timeout
for i in {1..10}; do
    if [ -S /var/spool/postfix/opendkim/opendkim.sock ]; then
        echo "OpenDKIM socket created successfully."
        break
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: OpenDKIM socket not found after 10 seconds"
        echo "Checking if OpenDKIM process is running..."
        ps aux | grep opendkim || echo "No opendkim process found"
        exit 1
    fi
    sleep 1
done

echo "Checking Postfix configuration..."
postfix check

echo "Starting Postfix in foreground..."
# Use exec to replace the shell process with Postfix
exec postfix start-fg