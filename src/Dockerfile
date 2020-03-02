ARG BASE
FROM ${BASE}

RUN mkdir -p /var/www/spotweb/
COPY ./spotweb/ /var/www/spotweb

RUN apk update && \
    apk add bash php php7-apache2 php7-cli php7-common php7-curl php7-gd php7-json php7-mbstring php7-session php7-pdo php7-opcache php7-xml php7-simplexml php7-xmlrpc php7-zip php7-gmp php7-dom php7-gettext openssl apache2 git shadow && \
    chmod +x /entry.sh && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /run/apache2 && \
    chown apache: /run/apache2

COPY ./app/run.sh /run.sh
RUN chmod u+x /run.sh

EXPOSE 80 443

CMD ["/run.sh"]


