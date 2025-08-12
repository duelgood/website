# Use the official nginx image as base
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy website files
COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/

# Create nginx configuration that enables SSI
RUN cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.shtml index.html;
    
    # Enable Server Side Includes
    ssi on;
    ssi_silent_errors off;
    ssi_types text/shtml;
    
    # Handle .shtml files
    location ~ \.shtml$ {
        ssi on;
        try_files $uri =404;
    }
    
    # Handle static files
    location /static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Handle includes directory (optional security measure)
    location /includes/ {
        internal;
    }
    
    # Default location block
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

# Set proper permissions
RUN chmod -R 644 /usr/share/nginx/html/ && \
    find /usr/share/nginx/html/ -type d -exec chmod 755 {} \;

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]