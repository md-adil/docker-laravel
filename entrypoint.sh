#!/bin/sh
set -e

# storage/ may be an empty volume (e.g. emptyDir with a read-only root filesystem),
# so recreate the layout Laravel and Octane expect before running anything
mkdir -p \
    storage/logs \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views

exec docker-php-entrypoint "$@"
