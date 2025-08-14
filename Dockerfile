FROM nginx:alpine

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

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
