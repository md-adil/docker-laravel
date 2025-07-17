FROM php:8.4-cli-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libbrotli-dev \
    libc-ares2 \
    libc-ares-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    sockets \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    opcache \
    zip \
    && docker-php-source delete

# Install Swoole with optimized build flags
RUN pecl install -D 'enable-openssl="yes" \
    enable-sockets="yes" \
    enable-mysqlnd="yes" \
    enable-swoole-curl="yes" \
    enable-swoole-json="yes" \
    enable-cares="yes"' \
    swoole-6.0.2 \
    && docker-php-ext-enable swoole

# PHP Production settings
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY php /usr/local/etc/php/conf.d

# Installing composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

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