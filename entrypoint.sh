#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────────────────────
# TaqaTechno — Odoo Enterprise Container Entrypoint
# ──────────────────────────────────────────────────────────────────────────────

# ── Validate that the Odoo source is available ────────────────────────────────
if [ "${BAKED_SOURCE:-0}" = "1" ]; then
    # Source baked into image at build time — skip mount validation
    if [ -d /opt/odoo/source/odoo ] || [ -f /opt/odoo/source/odoo-bin ] || [ -d /opt/odoo/source/setup ]; then
        SOURCE_MODE="BAKED"
    else
        echo "ERROR: BAKED_SOURCE=1 but source not found at /opt/odoo/source"
        exit 1
    fi
elif [ ! -d /opt/odoo/source/odoo ] && [ ! -f /opt/odoo/source/odoo-bin ] && [ ! -d /opt/odoo/source/setup ]; then
    echo "ERROR: Odoo source not found at /opt/odoo/source"
    echo "       Mount the taqat-techno/odoo-container repo:"
    echo "       -v /path/to/odoo-container:/opt/odoo/source:ro"
    exit 1
fi

# ── Optional: Source caching for Windows/WSL2 performance ─────────────────────
# SOURCE_CACHE=0 (default) — use bind mount directly (backward compatible)
# SOURCE_CACHE=1           — always cache source to fast ext4 volume
# SOURCE_CACHE=auto        — benchmark I/O, cache only if slow mount detected
# SOURCE_CACHE_FORCE=1     — force re-sync even if cache marker matches
CACHE_DIR="/var/lib/odoo/.source-cache"
SOURCE_VERSION_FILE="${CACHE_DIR}/.source-version"
SOURCE_MODE="${SOURCE_MODE:-bind mount}"
ODOO_SOURCE="/opt/odoo/source"

if [ "${SOURCE_CACHE:-0}" = "auto" ] && [ "${SOURCE_MODE}" != "BAKED" ]; then
    BENCH_START=$(date +%s%N 2>/dev/null || python -c "import time; print(int(time.time()*1e9))")
    find /opt/odoo/source/odoo/addons -maxdepth 2 -name '__manifest__.py' 2>/dev/null | head -50 | xargs cat > /dev/null 2>&1
    BENCH_END=$(date +%s%N 2>/dev/null || python -c "import time; print(int(time.time()*1e9))")
    BENCH_MS=$(( (BENCH_END - BENCH_START) / 1000000 ))
    if [ "$BENCH_MS" -gt 3000 ]; then
        echo "INFO: Slow I/O detected (${BENCH_MS}ms for 50 manifests). Enabling source cache."
        SOURCE_CACHE=1
    else
        echo "INFO: Fast I/O detected (${BENCH_MS}ms). Source cache not needed."
        SOURCE_CACHE=0
    fi
fi

if [ "${SOURCE_CACHE:-0}" = "1" ] && [ "${SOURCE_MODE}" != "BAKED" ]; then
    NEEDS_SYNC=0

    # Compute version marker from source
    SOURCE_MARKER=""
    if [ -f /opt/odoo/source/odoo/release.py ]; then
        SOURCE_MARKER=$(md5sum /opt/odoo/source/odoo/release.py 2>/dev/null | cut -d' ' -f1)
    fi
    if [ -z "$SOURCE_MARKER" ] && [ -f /opt/odoo/source/.git/HEAD ]; then
        SOURCE_MARKER=$(cat /opt/odoo/source/.git/HEAD 2>/dev/null)
    fi
    SOURCE_MARKER="${SOURCE_MARKER:-unknown}"

    # Check if cache is fresh
    if [ "${SOURCE_CACHE_FORCE:-0}" = "1" ]; then
        NEEDS_SYNC=1
        echo "INFO: Forced re-sync requested."
    elif [ -f "${SOURCE_VERSION_FILE}" ]; then
        CACHED_MARKER=$(cat "${SOURCE_VERSION_FILE}" 2>/dev/null)
        if [ "${CACHED_MARKER}" != "${SOURCE_MARKER}" ]; then
            NEEDS_SYNC=1
            echo "INFO: Source changed. Re-syncing cache..."
        else
            echo "INFO: Source cache is fresh. Using cached copy."
        fi
    else
        NEEDS_SYNC=1
        echo "INFO: No source cache found. Initial sync..."
    fi

    if [ "$NEEDS_SYNC" = "1" ]; then
        SYNC_START=$(date +%s)
        echo "INFO: Syncing source to ${CACHE_DIR}/ ..."
        mkdir -p "${CACHE_DIR}"
        rsync -a --delete \
            --exclude='*.pyc' \
            --exclude='__pycache__' \
            --exclude='.git' \
            --exclude='*.po' \
            --exclude='*.pot' \
            --exclude='node_modules' \
            /opt/odoo/source/ "${CACHE_DIR}/"
        echo "${SOURCE_MARKER}" > "${SOURCE_VERSION_FILE}"
        SYNC_END=$(date +%s)
        SYNC_DURATION=$((SYNC_END - SYNC_START))
        echo "INFO: Source sync completed in ${SYNC_DURATION}s"

        # Pre-compile Python bytecode for faster imports
        if [ ! -f "${CACHE_DIR}/.pyc-compiled" ] || [ "$NEEDS_SYNC" = "1" ]; then
            echo "INFO: Pre-compiling Python bytecode..."
            python -m compileall -q -j0 "${CACHE_DIR}/odoo/" 2>/dev/null || true
            touch "${CACHE_DIR}/.pyc-compiled"
            echo "INFO: Bytecode compilation complete."
        fi
    fi

    ODOO_SOURCE="${CACHE_DIR}"
    SOURCE_MODE="CACHED (${CACHE_DIR})"
fi

# Set PYTHONPATH so Odoo can import its modules without an editable install
export PYTHONPATH="${ODOO_SOURCE}"

# Auto-detect the correct entry point
# v19 uses setup/odoo; v14-v18 use odoo-bin
if [ -f "${ODOO_SOURCE}/setup/odoo" ]; then
    ODOO_SCRIPT="${ODOO_SOURCE}/setup/odoo"
elif [ -f "${ODOO_SOURCE}/odoo-bin" ]; then
    ODOO_SCRIPT="${ODOO_SOURCE}/odoo-bin"
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
echo "  Source:       ${SOURCE_MODE}"
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
