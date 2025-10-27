# ![DuelGood Logo](https://www.duelgood.org/static/logo.png)

This repository is public because DuelGood believes that open source builds trust, makes it easier to identify vulnerabilities, and invites community collaboration.

Visitors are encouraged to suggest accessibility, efficiency, and language improvements.

## Setup

To configure a fresh Arch instance, copy the Cloudflare
origin key into `/etc/ssl/cloudflare/key.pem` and the
origin cert into `/etc/ssl/cloudflare/cert.pem`.

Then, run

```sh
sudo chmod 644 "/etc/ssl/cloudflare/cert.pem"
sudo chmod 600 "/etc/ssl/cloudflare/key.pem"
```

Next, to set up email, run

```sh
mkdir -p /etc/opendkim/keys/duelgood.org
cd /etc/opendkim/keys/duelgood.org
opendkim-genkey -s mail -d duelgood.org
chown opendkim:opendkim mail.private
chmod 600 mail.private
```

Go to GitHub and create a personal access token with permission
to read, write, and delete packages.

Obtain Stripe secrets via the Stripe web interface.

```sh
export STRIPE_SECRET_KEY=sk_XXXX
export STRIPE_WEBHOOK_SECRET=whsec_XXXX
export GITHUB_GHCR_PAT=ghp_XXXX
export DKIM_PRIVATE_KEY=$(sudo cat /etc/opendkim/keys/duelgood.org/mail.private)
```

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

podman login -p=$GITHUB_GHCR_PAT
echo -n "$STRIPE_SECRET_KEY" | podman secret create stripe_secret_key -
echo -n "$STRIPE_WEBHOOK_SECRET" | podman secret create stripe_webhook_secret -
podman secret create dkim_private_key /etc/opendkim/keys/duelgood.org/mail.private
```

## Deploy

To apply any new changes and start the container, run the following commands.

```sh
cd "/opt/duelgood" || exit 1
podman-compose -p duelgood pull
podman-compose down --volumes --remove-orphans || true
podman rm -f duelgood-redis duelgood-backend duelgood-web 2>/dev/null || true
podman-compose -p duelgood up -d
```
