#!/bin/bash

echo "Starting email forwarder..."

# Create virtual aliases file dynamically from secret
if [ -f /run/secrets/smtp_username ]; then
    FORWARD_EMAIL=$(cat /run/secrets/smtp_username)
    echo "Forwarding emails to: $FORWARD_EMAIL"
    
    # Create virtual aliases file
    cat > /etc/postfix/virtual << EOF
# Forward all @duelgood.org emails to the configured email
@duelgood.org $FORWARD_EMAIL
noreply@duelgood.org $FORWARD_EMAIL
info@duelgood.org $FORWARD_EMAIL
EOF
    
    postmap /etc/postfix/virtual
    echo "Virtual aliases configured"
else
    echo "Warning: No SMTP username secret found. Email forwarding disabled."
fi

# Check configuration
postfix check

echo "Starting Postfix..."
exec /usr/lib/postfix/sbin/master -d