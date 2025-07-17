# Laravel Octane Docker Image (Swoole)

## Features
- PHP 8.4 CLI (Bookworm)
- Laravel Octane + Swoole 6.0.2
- Composer installed
- Production-ready and optimized

## Usage

### Docker Compose Example

```yaml
services:
  app:
    image: adil91/laravel-octane:latest
    volumes:
      - .:/var/www
    ports:
      - 8080:8080
    environment:
      - APP_ENV=production
    depends_on:
      - mysql