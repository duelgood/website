# DuelGood

DuelGood's website.

## Setup

Copy Cloudflare origin key into `/etc/ssl/cloudflare/key.pem`.
Copy Cloudflare origin cert into `/etc/ssl/cloudflare/cert.pem`

```sh
sudo chmod 644 "/etc/ssl/cloudflare/cert.pem"
sudo chmod 600 "/etc/ssl/cloudflare/key.pem"
```

Then, run

```sh
sudo mkdir -p /opt/duelgood && sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/docker-compose.yml?$(date +%s)" -o /opt/duelgood/docker-compose.yml && sudo curl -sSL "https://raw.githubusercontent.com/duelgood/website/refs/heads/main/startup.sh?$(date +%s)" | sh
```
