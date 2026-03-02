#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────────────────────
# TaqaTechno — Odoo Enterprise Container Entrypoint
# ──────────────────────────────────────────────────────────────────────────────

# Validate that the Odoo source is mounted
if [ ! -d /opt/odoo/source/odoo ] && [ ! -f /opt/odoo/source/odoo-bin ] && [ ! -d /opt/odoo/source/setup ]; then
    echo "ERROR: Odoo source not found at /opt/odoo/source"
    echo "       Mount the taqat-techno/odoo-container repo:"
    echo "       -v /path/to/odoo-container:/opt/odoo/source:ro"
    exit 1
fi

# Set PYTHONPATH so Odoo can import its modules without an editable install
export PYTHONPATH=/opt/odoo/source

# Auto-detect the correct entry point
# v19 uses setup/odoo; v14-v18 use odoo-bin
if [ -f /opt/odoo/source/setup/odoo ]; then
    ODOO_SCRIPT=/opt/odoo/source/setup/odoo
elif [ -f /opt/odoo/source/odoo-bin ]; then
    ODOO_SCRIPT=/opt/odoo/source/odoo-bin
else
    echo "ERROR: Cannot find Odoo entry point (setup/odoo or odoo-bin)"
    echo "       Is the correct odoo-container branch checked out?"
    exit 1
fi

# ── Optional: Wait for database to be ready ──────────────────────────────────
if [ "${WAIT_FOR_DB}" = "1" ] && [ -f /etc/odoo/odoo.conf ]; then
    DB_HOST=$(grep -E "^db_host\s*=" /etc/odoo/odoo.conf | sed 's/.*=\s*//' | tr -d '[:space:]')
    DB_PORT=$(grep -E "^db_port\s*=" /etc/odoo/odoo.conf | sed 's/.*=\s*//' | tr -d '[:space:]')
    DB_HOST="${DB_HOST:-db}"
    DB_PORT="${DB_PORT:-5432}"
    echo "INFO: Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
    for i in $(seq 1 30); do
        if python -c "import socket; s=socket.create_connection(('${DB_HOST}', ${DB_PORT}), timeout=2); s.close()" 2>/dev/null; then
            echo "INFO: PostgreSQL is ready."
            break
        fi
        if [ "$i" = "30" ]; then
            echo "WARNING: PostgreSQL not reachable after 30s. Starting Odoo anyway."
        fi
        sleep 1
    done
fi

# ── Startup banner ───────────────────────────────────────────────────────────
echo "================================================================"
echo "  TaqaTechno Odoo Container"
echo "  Odoo Version: ${ODOO_VERSION:-unknown}"
echo "  Script:       ${ODOO_SCRIPT}"
echo "  Config:       ${1:---config=/etc/odoo/odoo.conf}"
echo "  Time:         $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "================================================================"

# ── Validation warnings ──────────────────────────────────────────────────────

# Warn if data_dir is not configured (filestore will be ephemeral)
if [ -f /etc/odoo/odoo.conf ] && ! grep -q "^data_dir" /etc/odoo/odoo.conf; then
    echo "WARNING: 'data_dir' not set in odoo.conf. Filestore will be lost on container restart."
    echo "WARNING: Add 'data_dir = /var/lib/odoo' to your conf file for persistent assets."
fi

# Warn if workers > 0 but no proxy is configured
if [ -f /etc/odoo/odoo.conf ]; then
    WORKERS=$(grep -E "^workers\s*=" /etc/odoo/odoo.conf | sed 's/.*=\s*//' | tr -d '[:space:]')
    PROXY_MODE=$(grep -E "^proxy_mode\s*=" /etc/odoo/odoo.conf | sed 's/.*=\s*//' | tr -d '[:space:]')
    if [ "${WORKERS:-0}" != "0" ] && [ "${PROXY_MODE}" != "True" ]; then
        echo "WARNING: workers=${WORKERS} requires proxy_mode=True and an nginx reverse proxy."
        echo "WARNING: Without nginx, /websocket (port 8072) will not be reachable."
    fi
fi

# ── Build extra arguments ────────────────────────────────────────────────────
EXTRA_ARGS=""

# Dev mode: auto-reload + debug assets
if [ "${DEV_MODE}" = "1" ]; then
    echo "INFO: Dev mode enabled (--dev=all)"
    EXTRA_ARGS="${EXTRA_ARGS} --dev=all"
fi

# Log level override
if [ -n "${LOG_LEVEL}" ]; then
    echo "INFO: Log level override: ${LOG_LEVEL}"
    EXTRA_ARGS="${EXTRA_ARGS} --log-level=${LOG_LEVEL}"
fi

# Generic pass-through for arbitrary CLI flags
if [ -n "${ODOO_EXTRA_ARGS}" ]; then
    echo "INFO: Extra args: ${ODOO_EXTRA_ARGS}"
    EXTRA_ARGS="${EXTRA_ARGS} ${ODOO_EXTRA_ARGS}"
fi

# Remote debugger (debugpy is pre-installed in the image)
if [ "${ENABLE_DEBUGGER}" = "1" ]; then
    echo "INFO: Debugger enabled on port 5678 (waiting for IDE to attach...)"
    exec python -m debugpy \
        --listen 0.0.0.0:5678 \
        --wait-for-client \
        "${ODOO_SCRIPT}" \
        "$@" ${EXTRA_ARGS}
fi

exec python "${ODOO_SCRIPT}" "$@" ${EXTRA_ARGS}
