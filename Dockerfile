FROM phpswoole/swoole:php8.5

COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# swoole, sockets, pdo_mysql and composer are already included in the base image
RUN install-php-extensions \
    exif \
    pcntl \
    bcmath \
    zip

# Octane uses pgrep to stop worker processes on shutdown
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

# PHP Production settings
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY php /usr/local/etc/php/conf.d

ARG user=laravel
ARG uid=1000
ARG gid=1000

ENV USER=${user}
ENV OCTANE_SERVER=swoole \
    OCTANE_PORT=8080 \
    OCTANE_WORKERS=auto \
    OCTANE_TASK_WORKERS=auto \
    OCTANE_MAX_REQUESTS=500 \
    PHP_MEMORY_LIMIT=256M \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    LOG_CHANNEL=stderr

RUN groupadd -g ${gid} ${user} \
    && useradd -u ${uid} -g ${user} -d /home/${user} ${user} \
    && rm -rf /var/www \
    && mkdir -p /home/${user} /var/www \
    && chown -R ${user}:${user} /home/${user} /var/www

WORKDIR /var/www

# Numeric so Kubernetes can verify runAsNonRoot
USER ${uid}:${gid}

EXPOSE ${OCTANE_PORT}

# Skip the base image's supervisord entrypoint; run Octane directly
ENTRYPOINT [ "docker-php-entrypoint" ]

# storage/ may be an empty volume (e.g. emptyDir with a read-only root filesystem), so recreate its layout first
CMD [ "sh", "-c", "mkdir -p storage/logs storage/framework/cache/data storage/framework/sessions storage/framework/views && exec php artisan octane:start --host=0.0.0.0 --port=${OCTANE_PORT} --workers=${OCTANE_WORKERS} --task-workers=${OCTANE_TASK_WORKERS} --max-requests=${OCTANE_MAX_REQUESTS}" ]
