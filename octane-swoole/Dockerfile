FROM php:8.4-cli-bookworm

COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
    @composer \
    sockets \
    pdo_mysql \
    exif \
    pcntl \
    bcmath \
    zip \
    swoole

# PHP Production settings
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY php /usr/local/etc/php/conf.d

ARG user=laravel
ARG uid=1000
ARG gid=1000

ENV USER=${user}
ENV OCTANE_SERVER=swoole

RUN groupadd -g ${gid} ${user} \
    && useradd -u ${uid} -g ${user} -d /home/${user} ${user} \
    && mkdir -p /home/${user} /var/www \
    && chown -R ${user}:${user} /home/${user} /var/www \
    && rm -r /var/www/html

WORKDIR /var/www

USER ${USER}

CMD [ "php", "artisan", "octane:start", "--host=0.0.0.0", "--port=8080" ]