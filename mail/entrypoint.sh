#!/bin/bash
set -e

DKIM_KEY_PATH="/etc/opendkim/keys/duelgood.org/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

mkdir -p "$(dirname "$DKIM_KEY_PATH")"
cp "$SECRET_PATH" "$DKIM_KEY_PATH"
chown opendkim:opendkim "$DKIM_KEY_PATH"
chmod 600 "$DKIM_KEY_PATH"

# Ensure postfix is initialized
service postfix start > /dev/null 2>&1 || true
postfix stop 2>/dev/null || true
# Start OpenDKIM (background)
/usr/sbin/opendkim -f -x /etc/opendkim.conf &
# Start Postfix in foreground (this keeps the container alive)
exec /usr/sbin/postfix start-fg
