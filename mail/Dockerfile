FROM debian:bookworm-slim

RUN apt update && apt install -y postfix opendkim opendkim-tools mailutils && \
    rm -rf /var/lib/apt/lists/*

# Copy in your config files
COPY postfix/main.cf /etc/postfix/main.cf
COPY opendkim/opendkim.conf /etc/opendkim.conf
COPY opendkim/default /etc/default/opendkim

# Prepare directories
RUN mkdir -p /var/spool/postfix /etc/opendkim/keys && \
    chown -R opendkim:opendkim /etc/opendkim

EXPOSE 25
CMD service opendkim start && service postfix start && tail -f /var/log/mail.log
