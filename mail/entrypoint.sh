#!/bin/bash
set -e

DOMAIN=${DOMAIN:-duelgood.org}
DKIM_KEY_PATH="/etc/opendkim/keys/${DOMAIN}/mail.private"
SECRET_PATH="/run/secrets/dkim_private_key"

# Copy DKIM key from secret if provided
if [ -f "$SECRET_PATH" ]; then
  mkdir -p "$(dirname "$DKIM_KEY_PATH")"
  cp "$SECRET_PATH" "$DKIM_KEY_PATH"
  chown opendkim:opendkim "$DKIM_KEY_PATH"
  chmod 600 "$DKIM_KEY_PATH"
  echo "DKIM private key loaded for ${DOMAIN}"
else
  echo "No DKIM key found at $SECRET_PATH — mail signing disabled"
fi

# Ensure postfix is initialized
service postfix start > /dev/null 2>&1 || true
postfix stop 2>/dev/null || true

# Start OpenDKIM (background)
echo "Starting OpenDKIM..."
/usr/sbin/opendkim -f -x /etc/opendkim.conf &

# Start Postfix in foreground (this keeps the container alive)
echo "Starting Postfix..."
exec /usr/sbin/postfix start-fg
