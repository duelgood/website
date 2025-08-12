FROM nginx:alpine

# Enable SSI and set index.shtml as default index
RUN sed -i '/location \/ {/a \
    ssi on;\
    ssi_types text/shtml;\
    index index.shtml index.html index.htm;' /etc/nginx/conf.d/default.conf

# Add 'text/shtml shtml;' inside the existing types block in mime.types
RUN sed -i '/types {/a \    text/shtml shtml;' /etc/nginx/mime.types

COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
