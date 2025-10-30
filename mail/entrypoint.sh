#!/bin/bash
set -e
set -x

echo "Starting mail server..."

# Setup DKIM
DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

if [ -f "$SECRET_PATH" ]; then
    mkdir -p "$(dirname "$DKIM_KEY_PATH")"
    cp "$SECRET_PATH" "$DKIM_KEY_PATH"
    chown opendkim:opendkim "$DKIM_KEY_PATH"
    chmod 600 "$DKIM_KEY_PATH"
fi

# Setup directories
mkdir -p /var/spool/postfix/opendkim
chown opendkim:postfix /var/spool/postfix/opendkim
chmod 750 /var/spool/postfix/opendkim

# Start OpenDKIM
runuser -u opendkim -- /usr/sbin/opendkim -f -x /etc/opendkim.conf &

# Wait for socket
sleep 2

# Start Postfix
echo "Starting Postfix..."
exec /usr/lib/postfix/sbin/master -d