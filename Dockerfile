FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy certs
COPY certs/selfsigned.crt /etc/ssl/certs/selfsigned.crt
COPY certs/selfsigned.key /etc/ssl/private/selfsigned.key

COPY pages/ /usr/share/nginx/html/
COPY includes/ /usr/share/nginx/html/includes/
COPY static/ /usr/share/nginx/html/static/

RUN chmod -R 755 /usr/share/nginx/html/

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
