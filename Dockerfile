ARG base
FROM ${base}

RUN apt update && apt -y install curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev

# PHP Extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd opcache zip
RUN pecl install redis-6.0.2 && docker-php-ext-enable redis

# PHP Production settings
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY src/php /usr/local/etc/php/conf.d

# Installing composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Cleaning up
RUN rm -rf /var/lib/apt/lists/*

ARG user=laravel
ARG uid=1000

ENV USER=${user}

RUN useradd -u $uid -d /home/$user $user
RUN mkdir -p /home/$user && chown -R $user:$user /home/$user && chown -R $user:$user /var/www

WORKDIR /var/www
