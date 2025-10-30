# ![DuelGood Logo](web/static/logo.png)

This repository is public because DuelGood believes that open source builds trust, makes it easier to identify vulnerabilities, and invites community collaboration.

Visitors are encouraged to suggest accessibility, efficiency, and language improvements.

## Setup

### Certificate Bundles

To configure a fresh Arch instance, copy the Cloudflare
origin key into `/etc/ssl/cloudflare/key.pem` and the
origin cert into `/etc/ssl/cloudflare/cert.pem`.

Then, run

```sh
sudo chmod 644 "/etc/ssl/cloudflare/cert.pem"
sudo chmod 600 "/etc/ssl/cloudflare/key.pem"
```

### Gmail

Go to Google Account settings, enable 2FA, generate and save app password, then run

```sh
export SMTP_USERNAME=your-email@gmail.com
export SMTP_PASSWORD=your-16-character-app-password
```

### GitHub

Go to GitHub and create a [personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) with permission
to read, write, and delete packages. Export with

```sh
export GITHUB_GHCR_PAT=ghp_XXXX
```

### Stripe

Obtain Stripe secrets via the Stripe web interface, then run

```sh
export STRIPE_SECRET_KEY=sk_XXXX
export STRIPE_WEBHOOK_SECRET=whsec_XXXX
```

### Configuration

Then, run

```sh
sudo mkdir -p /opt/duelgood
sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/compose.yml?$(date +%s)" -o /opt/duelgood/compose.yml

grep -qxF 'net.ipv4.ip_unprivileged_port_start=80' /etc/sysctl.conf || echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

sudo pacman -Syu --noconfirm
sudo pacman -Sy --noconfirm podman podman-compose
systemctl --user enable --now podman.socket
mkdir -p ~/.config/systemd/user
sudo loginctl enable-linger $USER

podman login ghcr.io -p=$GITHUB_GHCR_PAT

# Create secrets
echo -n "$STRIPE_SECRET_KEY" | podman secret create stripe_secret_key -
echo -n "$STRIPE_WEBHOOK_SECRET" | podman secret create stripe_webhook_secret -
echo -n "$SMTP_USERNAME" | podman secret create smtp_username -
echo -n "$SMTP_PASSWORD" | podman secret create smtp_password -

# Create email configuration
sudo mkdir -p /opt/duelgood/postfix
echo "$SMTP_USERNAME" | sudo tee /opt/duelgood/postfix/forward_to_email
```

## Deploy

To apply any new changes and start the container, run the following commands.

```sh
cd "/opt/duelgood" || exit 1
podman-compose -p duelgood pull
podman-compose down --volumes --remove-orphans || true
podman rm -f duelgood-redis duelgood-mail duelgood-backend duelgood-web 2>/dev/null || true
podman-compose --verbose -p duelgood up -d
```
