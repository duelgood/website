# DuelGood

DuelGood's website.

## Secrets

Copy Cloudflare origin key into `/etc/ssl/cloudflare/key.pem`.
Copy Cloudflare origin cert into `/etc/ssl/cloudflare/cert.pem`

```sh
sudo chmod 644 "/etc/ssl/cloudflare/cert.pem"
sudo chmod 600 "/etc/ssl/cloudflare/key.pem"
```

Go to GitHub and create a personal access token with permission
to read, write, and delete packages.

Obtain Stripe secrets via the Stripe web interface.

```sh
export STRIPE_SECRET_KEY=sk_XXXX
export STRIPE_WEBHOOK_SECRET=whsec_XXXX
export GITHUB_GHCR_PAT=ghp_XXXX
```

Then, run

```sh
echo -n "$STRIPE_SECRET_KEY" | podman secret create stripe_secret_key -
echo -n "$STRIPE_WEBHOOK_SECRET" | podman secret create stripe_webhook_secret -
```

## Login

`podman login ghcr.io -p=$GITHUB_GHCR_PAT`

## Deploy

To start the containers, run

```sh
sudo mkdir -p /opt/duelgood && sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/compose.yml?$(date +%s)" -o /opt/duelgood/compose.yml && sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/startup.sh?$(date +%s)" | sh
```
