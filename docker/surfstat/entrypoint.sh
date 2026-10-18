#!/usr/bin/env bash
#
# surfstat entrypoint (PID 1 for the product image).
#
# Thin wrapper over the base image's entrypoint: it only resets the surfstat boot
# gate, then hands off to the base entrypoint, which prepares Postgres + TLS and
# execs supervisord. supervisord then starts the base programs AND the surfstat
# programs (surfstat-db + surfstat-api) it picked up from /etc/supervisor/conf.d.
set -euo pipefail

RUN_DIR=/run/surfstat
mkdir -p "$RUN_DIR"
# Fresh boot: force the surfstat DB gate closed so surfstat-api waits for it.
rm -f "$RUN_DIR/db.done"

exec /opt/superset/entrypoint.sh
