FROM nginx:alpine

# Install OpenSSL for generating self-signed certificates if needed
RUN apk add --no-cache openssl

# Copy website files
COPY pages/ /var/www/html/
COPY includes/ /var/www/html/includes/
COPY static/ /var/www/html/static/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

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
