FROM nginx:alpine

# Install openssl for cert generation
RUN apk add --no-cache openssl

# Remove default nginx config and add your own
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy website files
COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/

# Set proper permissions
RUN chmod -R 755 /usr/share/nginx/html/

# Add entrypoint script for runtime cert generation
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80 443

CMD ["/docker-entrypoint.sh"]
