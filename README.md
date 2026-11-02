# Laravel Octane Docker Image (Swoole)

Production base image for Laravel APIs running on [Laravel Octane](https://laravel.com/docs/octane) with Swoole, built for Docker and Kubernetes.

## Features

- PHP 8.5 CLI on Debian Trixie, based on [`phpswoole/swoole`](https://hub.docker.com/r/phpswoole/swoole)
- Swoole 6.2 with OpenSSL, cURL, sockets and Brotli
- Extensions: `pdo_mysql`, `redis`, `sockets`, `pcntl`, `bcmath`, `exif`, `zip`, OPcache
- Composer included
- Production `php.ini`, OPcache enabled for the CLI, `expose_php` off
- PHP errors and Laravel logs go to stderr
- Runs as non-root user `1000:1000`
- Works with a read-only root filesystem
- Multi-arch: `linux/amd64` and `linux/arm64`

## Tags

| Debian | Alpine | Description |
|---|---|---|
| `latest` | `latest-alpine` | Latest build |
| `1.2.3` | `1.2.3-alpine` | Release built from git tag `v1.2.3` |

Swoole isn't pinned: each build uses the newest Swoole that `phpswoole/swoole` ships for PHP 8.5, which can be a release candidate.

The Alpine image is about 4× smaller. Debian (glibc) is the safer default under load; load-test Alpine (musl) before using it in production.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `OCTANE_PORT` | `8080` | Port Octane listens on |
| `OCTANE_WORKERS` | `auto` | Number of workers. `auto` uses the CPU count, which in Kubernetes is the **node's** CPUs, not the pod's limit. Set this explicitly. |
| `OCTANE_TASK_WORKERS` | `auto` | Number of task workers |
| `OCTANE_MAX_REQUESTS` | `500` | Requests a worker handles before it restarts |
| `PHP_MEMORY_LIMIT` | `256M` | PHP `memory_limit` per worker |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | Set to `1` in local development so code changes are picked up |
| `LOG_CHANNEL` | `stderr` | Laravel log channel |

Your app needs `laravel/octane` installed:

```bash
composer require laravel/octane
php artisan octane:install --server=swoole
```

## Building your app image

Bake the code into the image rather than mounting it:

```dockerfile
FROM adil91/laravel-octane:latest

COPY --chown=1000:1000 composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

COPY --chown=1000:1000 . .
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev \
    && php artisan route:cache \
    && php artisan event:cache
```

Don't run `config:cache` at build time: it stores the build environment's values in the image, while Docker and Kubernetes supply env vars when the container starts. Octane loads the config once per worker, so a config cache gains little anyway.

Add a `.dockerignore`:

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

## Docker Compose (local development)

```yaml
services:
  app:
    build: .
    ports:
      - 8080:8080
    volumes:
      - .:/var/www
    environment:
      APP_ENV: local
      OCTANE_WORKERS: 2
      PHP_OPCACHE_VALIDATE_TIMESTAMPS: 1
    depends_on:
      - mysql
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
          env:
            - name: OCTANE_WORKERS
              value: "2" # match the CPU limit
            - name: OCTANE_TASK_WORKERS
              value: "1"
          envFrom:
            - secretRef:
                name: api-env
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
              mountPath: /tmp
      volumes:
        - name: storage
          emptyDir: {}
        - name: tmp
          emptyDir: {}
```

The image recreates the `storage/` directory layout on startup, so an empty volume works. For an API on several replicas, use Redis or the database for cache, sessions and queues rather than local files.
