#!/usr/bin/env bash
#
# surfstat-db — one-shot (run once per boot by supervisord, priority 150).
#
# The surfstat backend keeps its own state (native charts, dashboards, settings,
# the intake/cases tables) in a `surfstat` database next to Superset's `superset`
# database in the same internal Postgres. The backend CREATEs its tables on boot,
# but it cannot create its own role/database — so do that here first.
#
# Internal Postgres only. When an external/shared Postgres is configured
# (PG_INTERNAL=false, set by the base entrypoint) the role + database are expected
# to already exist (the deploy init SQL creates them), so this is a no-op gate.
set -uo pipefail

RUN_DIR=/run/surfstat
mkdir -p "$RUN_DIR"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
SURFSTAT_DB_USER="${SURFSTAT_DB_USER:-surfstat}"
SURFSTAT_DB_PASS="${SURFSTAT_DB_PASS:-surfstat}"
SURFSTAT_DB_NAME="${SURFSTAT_DB_NAME:-surfstat}"

log() { echo "[surfstat-db] $*"; }

log "waiting for Postgres at ${DB_HOST}:${DB_PORT}..."
until pg_isready -q -h "$DB_HOST" -p "$DB_PORT"; do sleep 2; done

if [ "${PG_INTERNAL:-true}" = "true" ]; then
    if ! su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${SURFSTAT_DB_USER}'\"" | grep -q 1; then
        log "creating role ${SURFSTAT_DB_USER}"
        su postgres -c "psql -c \"CREATE ROLE \\\"${SURFSTAT_DB_USER}\\\" LOGIN PASSWORD '${SURFSTAT_DB_PASS}'\""
    else
        # Keep the password in sync with the env in case it changed between boots.
        su postgres -c "psql -c \"ALTER ROLE \\\"${SURFSTAT_DB_USER}\\\" LOGIN PASSWORD '${SURFSTAT_DB_PASS}'\"" || true
    fi
    if ! su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${SURFSTAT_DB_NAME}'\"" | grep -q 1; then
        log "creating database ${SURFSTAT_DB_NAME}"
        su postgres -c "createdb -O '${SURFSTAT_DB_USER}' '${SURFSTAT_DB_NAME}'"
    fi
else
    log "external Postgres — expecting database '${SURFSTAT_DB_NAME}' + role '${SURFSTAT_DB_USER}' to already exist"
fi

touch "$RUN_DIR/db.done"
log "done — surfstat database ready"
