FROM nginx:alpine

# Install Python + OCI CLI
RUN apk add --no-cache python3 py3-pip bash curl jq && \
    pip install oci-cli && \
    mkdir -p /etc/ssl/cloudflare && chmod 700 /etc/ssl/cloudflare

# Copy website files
COPY pages/ /var/www/html/
COPY includes/ /var/www/html/includes/
COPY static/ /var/www/html/static/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create log directory
RUN mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/www/html && \
    chmod -R 755 /var/www/html

EXPOSE 80 443

# Fetch cert + key from Vault at container start, then run nginx
ENTRYPOINT bash -c "\
    echo '[INFO] Fetching Cloudflare Origin certs from OCI Vault...' && \
    oci secrets secret-bundle get \
        --secret-id ocid1.vaultsecret.oc1..CERT_SECRET_ID \
        --auth instance_principal \
        --query \"data.\\\"secret-bundle-content\\\".content\" \
        --raw-output | base64 -d > /etc/ssl/cloudflare/origin.crt && \
    oci secrets secret-bundle get \
        --secret-id ocid1.vaultsecret.oc1..KEY_SECRET_ID \
        --auth instance_principal \
        --query \"data.\\\"secret-bundle-content\\\".content\" \
        --raw-output | base64 -d > /etc/ssl/cloudflare/origin.key && \
    chmod 600 /etc/ssl/cloudflare/origin.key && \
    echo '[INFO] Certs fetched successfully.' && \
    nginx -g 'daemon off;'"
