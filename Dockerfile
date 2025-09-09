FROM docker.io/library/nginx:alpine

# Install required packages
RUN apk add \
    openssl \
    curl \
    ca-certificates \
    python3 \
    py3-pip \
    jq

# Create directories
RUN mkdir -p /var/www/html /var/log/nginx /etc/ssl/cloudflare

# Copy website files
COPY pages/ /var/www/html/pages/
COPY pages/includes/ /var/www/html/pages/includes/
COPY static/ /var/www/html/static/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Set permissions
RUN chown -R nginx:nginx /var/www/html && chmod -R 755 /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]