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
    ODOO_BIN="python /opt/odoo/source/setup/odoo"
elif [ -f /opt/odoo/source/odoo-bin ]; then
    ODOO_BIN="python /opt/odoo/source/odoo-bin"
else
    echo "ERROR: Cannot find Odoo entry point (setup/odoo or odoo-bin)"
    echo "       Is the correct odoo-container branch checked out?"
    exit 1
fi

# Build extra arguments
EXTRA_ARGS=""

# Dev mode: auto-reload + debug assets
if [ "${DEV_MODE}" = "1" ]; then
    echo "INFO: Dev mode enabled (--dev=all)"
    EXTRA_ARGS="${EXTRA_ARGS} --dev=all"
fi

# Remote debugger (debugpy)
if [ "${ENABLE_DEBUGGER}" = "1" ]; then
    echo "INFO: Debugger enabled on port 5678 (waiting for IDE to attach...)"
    pip install --quiet debugpy
    exec python -m debugpy \
        --listen 0.0.0.0:5678 \
        --wait-for-client \
        /opt/odoo/source/setup/odoo 2>/dev/null \
        || exec python -m debugpy \
            --listen 0.0.0.0:5678 \
            --wait-for-client \
            /opt/odoo/source/odoo-bin \
        "$@" ${EXTRA_ARGS}
fi

exec ${ODOO_BIN} "$@" ${EXTRA_ARGS}
