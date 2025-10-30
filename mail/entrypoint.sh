#!/bin/bash
set -e
set -x

echo "Starting mail server v1.1"

# Setup DKIM
DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

if [ -f "$SECRET_PATH" ]; then
    mkdir -p "$(dirname "$DKIM_KEY_PATH")"
    cp "$SECRET_PATH" "$DKIM_KEY_PATH"
    chown opendkim:opendkim "$DKIM_KEY_PATH"
    chmod 600 "$DKIM_KEY_PATH"
    echo "DKIM key setup complete."
fi

# Setup directories
mkdir -p /var/spool/postfix/opendkim
chown opendkim:postfix /var/spool/postfix/opendkim
chmod 750 /var/spool/postfix/opendkim

# Start OpenDKIM
echo "Starting OpenDKIM..."
runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf &

# Wait for socket
sleep 2

# Check Postfix configuration
echo "Checking Postfix configuration..."
postfix check

# Test if master can start
echo "Testing Postfix master startup..."
/usr/lib/postfix/sbin/master -d &
MASTER_PID=$!
sleep 3

if kill -0 $MASTER_PID 2>/dev/null; then
    echo "Postfix master started successfully (PID: $MASTER_PID)"
    echo "Container is running..."
    wait $MASTER_PID
else
    echo "Postfix master failed to start"
    echo "Last few lines of syslog:"
    tail -20 /var/log/syslog || echo "No syslog available"
    exit 1
fi