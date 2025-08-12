FROM nginx:alpine

# Enable SSI and set index.shtml as the default index file
RUN sed -i '/location \/ {/a \
    ssi on;\
    ssi_types text/shtml;\
    index index.shtml index.html index.htm;' /etc/nginx/conf.d/default.conf

# Ensure nginx serves .shtml files with the correct MIME type
RUN echo 'types {\n  text/shtml shtml;\n}' >> /etc/nginx/mime.types

# Copy site content: pages go to web root; includes/static as is
COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
