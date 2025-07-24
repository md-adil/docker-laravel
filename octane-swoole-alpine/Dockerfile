FROM phpswoole/swoole:6.0-php8.4-alpine

COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/extensions

RUN extensions exif pcntl bcmath zip opcache

# PHP Production settings
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY php /usr/local/etc/php/conf.d

ARG user=laravel
ARG uid=1000
ARG gid=1000
ARG homedir=/var/www

ENV USER=${user}
ENV OCTANE_SERVER=swoole

RUN adduser --disabled-password -u ${uid} --home ${homedir} ${user} \
    && chown -R ${user}:${user} ${homedir} \
    && rm -r /var/www/html

WORKDIR ${homedir}

USER ${USER}

CMD [ "php", "artisan", "octane:start", "--host=0.0.0.0", "--port=8080" ]