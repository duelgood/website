# DuelGood

DuelGood's website.

## Setup

### Secrets

Copy Cloudflare origin key into `/etc/ssl/cloudflare/key.pem`.
Copy Cloudflare origin cert into `/etc/ssl/cloudflare/cert.pem`

```sh
sudo chmod 644 "/etc/ssl/cloudflare/cert.pem"
sudo chmod 600 "/etc/ssl/cloudflare/key.pem"
```

Create the following environment variables:

```sh

```

### Deploying

To start the containers, run

```sh
sudo mkdir -p /opt/duelgood && sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/compose.yml?$(date +%s)" -o /opt/duelgood/compose.yml && sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/startup.sh?$(date +%s)" | sh
```
