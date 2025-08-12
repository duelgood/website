FROM nginx:alpine

# Enable SSI and configure index files, and set SSI for text/html (covers .shtml)
RUN sed -i '/location \/ {/a \
    ssi on;\
    ssi_types text/html;\
    index index.shtml index.html index.htm;' /etc/nginx/conf.d/default.conf

COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
