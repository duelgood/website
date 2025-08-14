# DuelGood

A website for canceling opposing political donations and directing the difference to charity.

## Development

Start the development server with live reload:

```bash
make dev
```

Stop the development server:

```bash
make dev-down
```

View logs:

```bash
make dev-logs
```

## Production

Start production server:

```bash
make prod
```

Stop production server:

```bash
make prod-down
```

## Project Structure

- `pages/` - SHTML pages with server-side includes
- `includes/` - Reusable header and footer components
- `static/` - CSS, images, and other static assets
- `nginx.conf` - Production nginx configuration with HTTPS
- `nginx.conf.dev` - Development nginx configuration (HTTP only)

## Deployment

The site is containerized and ready for deployment. SSL certificates should be placed in `/etc/ssl/cloudflare/` in the production container.

## Health Check

Check if the service is running:

```bash
make health
```

Or visit: http://localhost/health
