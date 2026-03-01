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

# Warn if data_dir is not configured (filestore will be ephemeral)
if [ -f /etc/odoo/odoo.conf ] && ! grep -q "^data_dir" /etc/odoo/odoo.conf; then
    echo "WARNING: 'data_dir' not set in odoo.conf. Filestore will be lost on container restart."
    echo "WARNING: Add 'data_dir = /var/lib/odoo' to your conf file for persistent assets."
fi

# Build extra arguments
EXTRA_ARGS=""

# Dev mode: auto-reload + debug assets
if [ "${DEV_MODE}" = "1" ]; then
    echo "INFO: Dev mode enabled (--dev=all)"
    EXTRA_ARGS="${EXTRA_ARGS} --dev=all"
fi

# Remote debugger (debugpy is pre-installed in the image)
if [ "${ENABLE_DEBUGGER}" = "1" ]; then
    echo "INFO: Debugger enabled on port 5678 (waiting for IDE to attach...)"
    exec python -m debugpy \
        --listen 0.0.0.0:5678 \
        --wait-for-client \
        ${ODOO_SCRIPT} \
        "$@" ${EXTRA_ARGS}
fi

exec python ${ODOO_SCRIPT} "$@" ${EXTRA_ARGS}
