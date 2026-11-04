# Laravel Octane Docker Image (Swoole)

A ready-to-use base image for running Laravel apps on [Laravel Octane](https://laravel.com/docs/octane) with Swoole. It's built for production on Docker and Kubernetes and also works for local development.

Octane boots your app once and keeps it in memory, so requests skip the framework bootstrap and are much faster than with PHP-FPM.

**Source:** [github.com/md-adil/docker-laravel](https://github.com/md-adil/docker-laravel)

## What's included

- PHP 8.5 (CLI) on Debian Trixie, based on [`phpswoole/swoole`](https://hub.docker.com/r/phpswoole/swoole)
- Swoole 6.2 with OpenSSL, cURL, sockets and Brotli
- PHP extensions: `pdo_mysql`, `redis`, `sockets`, `pcntl`, `bcmath`, `exif`, `zip`, OPcache
- Composer
- Production `php.ini`, with OPcache enabled for the CLI and `expose_php` off
- PHP errors and Laravel logs go to stderr, so `docker logs` shows them
- Runs as a non-root user (`1000:1000`)
- Works with a read-only root filesystem
- Multi-arch: `linux/amd64` and `linux/arm64` (Apple Silicon, AWS Graviton)

## Tags

| Debian | Alpine | Description |
|---|---|---|
| `latest` | `latest-alpine` | Latest build |
| `1.2.3` | `1.2.3-alpine` | Release built from git tag `v1.2.3` |

**Which one should I use?** Start with Debian (`latest`). Alpine is about 4× smaller, but it uses musl instead of glibc, which can behave differently under load. Load-test it before you use it in production.

For production, pin a version tag (for example `1.2.3`) rather than `latest`, so your builds don't change unexpectedly. Swoole itself isn't pinned: each build uses the newest Swoole that `phpswoole/swoole` ships for PHP 8.5, which can be a release candidate.

## Quick start

You need [Docker](https://docs.docker.com/get-docker/) and a Laravel project (Laravel 11 or newer for the `/up` health route used below).

### 1. Install Octane in your project

Run this in your project folder:

```bash
composer require laravel/octane
php artisan octane:install --server=swoole
```

No PHP on your machine? Run the same commands inside the image:

```bash
docker run --rm -v "$PWD":/var/www adil91/laravel-octane composer require laravel/octane
docker run --rm -v "$PWD":/var/www adil91/laravel-octane php artisan octane:install --server=swoole
```

### 2. Add a `Dockerfile` to your project

```dockerfile
FROM adil91/laravel-octane:latest

# Install dependencies first so Docker can cache this layer
COPY --chown=1000:1000 composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

# Copy the rest of the app
COPY --chown=1000:1000 . .
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev \
    && php artisan route:cache \
    && php artisan event:cache
```

Don't run `php artisan config:cache` in the Dockerfile. It saves the values present at build time into the image, but your real settings (database password, `APP_KEY`, and so on) are supplied when the container starts. Octane loads the config only once per worker anyway, so caching it gains little.

### 3. Add a `.dockerignore`

This keeps secrets and unneeded files out of the image:

```
.git
.env
node_modules
vendor
storage/logs/*
storage/framework/cache/*
storage/framework/sessions/*
storage/framework/views/*
tests
```

### 4. Build and run

```bash
docker build -t my-app .
docker run --rm -p 8080:8080 \
  -e APP_KEY="base64:..." \
  -e APP_ENV=production \
  my-app
```

Open [http://localhost:8080](http://localhost:8080).

- **`APP_KEY`** is required. Copy it from your `.env`, or generate a new one with `php artisan key:generate --show`.
- Pass any other settings your app needs (database, cache, mail) with `-e NAME=value`, or all at once with `--env-file .env`. `127.0.0.1` inside a container means the container itself, so `DB_HOST=127.0.0.1` won't reach a database on your machine. Use `host.docker.internal` on Docker Desktop, or a service name in Compose.

## Configuration

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `OCTANE_HOST` | `0.0.0.0` | Address Octane binds to |
| `OCTANE_PORT` | `8080` | Port Octane listens on. It's above 1024 because the container doesn't run as root. |
| `PHP_MEMORY_LIMIT` | `256M` | PHP `memory_limit` per worker |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | Set to `1` in local development, so reloaded workers see your code changes (see [Local development](#local-development-with-docker-compose)) |
| `LOG_CHANNEL` | `stderr` | Laravel log channel |

All your usual Laravel variables (`APP_KEY`, `APP_ENV`, `DB_*`, `REDIS_*`, ...) work as normal.

### Command and workers

The default command is:

```sh
php artisan octane:start --workers=auto --task-workers=auto --max-requests=500
```

| Option | Meaning |
|---|---|
| `--workers` | How many requests are handled at the same time. `auto` = one per CPU. |
| `--task-workers` | Workers for [concurrent tasks](https://laravel.com/docs/octane#concurrent-tasks) |
| `--max-requests` | A worker restarts after this many requests, which limits memory leaks |

To change them, override the command: `command:` in Compose, `args:` in Kubernetes, or append it to `docker run`:

```bash
docker run --rm -p 8080:8080 -e APP_KEY="base64:..." my-app \
  php artisan octane:start --workers=4 --task-workers=2 --max-requests=1000
```

In Kubernetes, `auto` counts the **node's** CPUs, not your pod's CPU limit, so always set `--workers` there.

Memory: each worker uses up to `PHP_MEMORY_LIMIT`, so give the container at least `workers × PHP_MEMORY_LIMIT` plus some headroom.

### The `storage/` folder

On startup, the image creates the folders Laravel and Octane need inside `storage/`. This means `storage/` can be an empty volume (for example a Kubernetes `emptyDir`). Folder creation also runs when you override the command.

## Local development with Docker Compose

This setup mounts your project folder into the container, so you edit code on your machine as usual.

`compose.yaml`:

```yaml
services:
  app:
    image: adil91/laravel-octane:latest
    ports:
      - 8080:8080
    volumes:
      - .:/var/www
    environment:
      APP_ENV: local
      APP_DEBUG: "true"
      PHP_OPCACHE_VALIDATE_TIMESTAMPS: 1
      DB_CONNECTION: mysql
      DB_HOST: mysql
      DB_DATABASE: laravel
      DB_USERNAME: laravel
      DB_PASSWORD: secret
    command: php artisan octane:start --workers=2 --task-workers=1 --max-requests=500
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:9.7
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: secret
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      retries: 10

volumes:
  mysql-data:
```

Environment variables set here override the values in your `.env`.

First run:

```bash
docker compose run --rm app composer install
docker compose run --rm app php artisan key:generate
docker compose up -d
docker compose exec app php artisan migrate
```

Then open [http://localhost:8080](http://localhost:8080).

**Seeing your code changes:** Octane keeps your app in memory, so a changed file isn't picked up until the workers reload:

```bash
docker compose exec app php artisan octane:reload
```

Run any other command the same way, for example `docker compose exec app php artisan tinker`.

## Queue workers and the scheduler

Use the same image with a different command. In Compose, add these services next to `app`. They need the same image, volumes and environment as `app`; the `x-app` anchor below avoids repeating them:

```yaml
x-app: &app
  image: adil91/laravel-octane:latest
  volumes:
    - .:/var/www
  environment:
    DB_HOST: mysql
    # ...same as the app service

services:
  queue:
    <<: *app
    command: php artisan queue:work --tries=3

  scheduler:
    <<: *app
    command: php artisan schedule:work
```

In production, run them as separate containers (or Kubernetes Deployments) from your app image.

## Adding PHP extensions

Need something that isn't included, such as `pdo_pgsql` for PostgreSQL, `gd` or `intl`? The image ships [`install-php-extensions`](https://github.com/mlocati/docker-php-extension-installer):

```dockerfile
FROM adil91/laravel-octane:latest

USER root
RUN install-php-extensions pdo_pgsql gd intl
USER 1000:1000

# ...rest of your Dockerfile
```

Switch back to `USER 1000:1000` afterwards, so the app doesn't run as root.

## Frontend assets (Vite)

The image has no Node.js. If your app has a frontend, build the assets in a separate stage and copy the result in:

```dockerfile
FROM node:26-alpine AS assets
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM adil91/laravel-octane:latest
COPY --chown=1000:1000 composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY --chown=1000:1000 . .
COPY --from=assets --chown=1000:1000 /app/public/build ./public/build
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev \
    && php artisan route:cache \
    && php artisan event:cache
```

## Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: api
          image: your-registry/your-api:1.0.0
          ports:
            - containerPort: 8080
          args: # --workers should match the CPU limit
            ["php", "artisan", "octane:start", "--workers=2", "--task-workers=1", "--max-requests=500"]
          envFrom:
            - secretRef:
                name: api-env # APP_KEY, DB_*, etc.
          resources:
            requests:
              cpu: "1"
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 1Gi # keep above workers × PHP_MEMORY_LIMIT
          readinessProbe:
            httpGet:
              path: /up
              port: 8080
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /up
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          lifecycle:
            preStop:
              # let the Service stop routing traffic before Octane shuts down
              sleep:
                seconds: 5
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: storage
              mountPath: /var/www/storage
            - name: tmp
              mountPath: /tmp # PHP needs a writable /tmp, e.g. for file uploads
      volumes:
        - name: storage
          emptyDir: {}
        - name: tmp
          emptyDir: {}
```

Create the secret from your production env file with `kubectl create secret generic api-env --from-env-file=.env.production`.

With several replicas, each pod has its own `storage/`. Use Redis or the database for cache, sessions and queues instead of local files, and object storage (such as S3) for uploads.

## Troubleshooting

**`No application encryption key has been specified`**
`APP_KEY` isn't set. Pass it as an environment variable (see [Build and run](#4-build-and-run)).

**`Permission denied` writing to `storage/` or `bootstrap/cache/`**
The container runs as user `1000`. On Linux, if your user has a different ID (check with `id -u`), mounted folders may not be writable. Fix this with `sudo chown -R 1000:1000 storage bootstrap/cache`, or build the base image with your own IDs: `--build-arg uid=$(id -u) --build-arg gid=$(id -g)`.

**My code changes don't show up**
Octane keeps the app in memory. Run `php artisan octane:reload` and make sure `PHP_OPCACHE_VALIDATE_TIMESTAMPS=1` is set.

**`Connection refused` to the database**
Inside a container, `127.0.0.1` is the container itself. Use the Compose service name (`mysql`), or `host.docker.internal` for a database on your machine.

**Values from `--env-file` include quote marks**
`docker run --env-file` doesn't strip quotes the way Laravel's `.env` loader does. Write `APP_NAME=My App`, not `APP_NAME="My App"`.

**Wrong URLs or `http://` links behind a load balancer**
Configure Laravel's [trusted proxies](https://laravel.com/docs/requests#configuring-trusted-proxies) so it respects the `X-Forwarded-*` headers.

**Something works with `php artisan serve` but breaks under Octane**
Octane reuses the app between requests, so data kept in static properties or singletons can leak from one request to the next. See [Dependency injection and Octane](https://laravel.com/docs/octane#dependency-injection-and-octane).
