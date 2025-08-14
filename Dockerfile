FROM nginx:alpine

# Install OpenSSL for generating self-signed certificates if needed
RUN apk add --no-cache openssl

# Copy website files
COPY pages/ /var/www/html/
COPY includes/ /var/www/html/includes/
COPY static/ /var/www/html/static/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create SSL directory and generate self-signed certificates for local development
# In production with Cloudflare, these won't be used but nginx still needs them
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create log directory
RUN mkdir -p /var/log/nginx

# Set permissions
RUN chown -R nginx:nginx /var/www/html && \
    chmod -R 755 /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
