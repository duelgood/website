FROM nginx:alpine

# Create custom nginx configuration for SSI
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy website files
COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/
1
# Set proper permissions
RUN chmod -R 755 /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]