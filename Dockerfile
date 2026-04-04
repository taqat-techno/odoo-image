# ──────────────────────────────────────────────────────────────────────────────
# TaqaTechno — Odoo Enterprise Base Image
# Supports versions 14 through 19 via build args.
#
# Build:
#   docker build --build-arg ODOO_VERSION=19 --build-arg PYTHON_VERSION=3.12 \
#     --build-arg DEBIAN_CODENAME=bookworm -t alakosha/odoo-image:19.0 .
#
# Pull pre-built:
#   docker pull alakosha/odoo-image:19.0
# ──────────────────────────────────────────────────────────────────────────────

ARG ODOO_VERSION=19
ARG PYTHON_VERSION=3.12
ARG DEBIAN_CODENAME=bookworm

# ── Stage 1: Builder — compile Python packages ────────────────────────────────
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_CODENAME} AS builder

ARG ODOO_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1

# Build-time headers and compilers (not carried into final image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    libfreetype6-dev \
    libffi-dev \
    gcc \
    g++ \
    make \
    python3-dev \
 && rm -rf /var/lib/apt/lists/*

COPY requirements-*.txt /tmp/
RUN pip install --no-cache-dir --upgrade pip "setuptools<80" \
 && pip install --no-cache-dir \
    -r /tmp/requirements-${ODOO_VERSION}.txt \
    debugpy \
 && rm /tmp/requirements-*.txt

# ── Stage 2: Runtime — lean image, no build tools ─────────────────────────────
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_CODENAME}

ARG ODOO_VERSION
ARG PYTHON_VERSION
ARG DEBIAN_CODENAME
ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="TaqaTechno <info@taqatechno.com>" \
      org.opencontainers.image.title="Odoo Enterprise ${ODOO_VERSION}" \
      org.opencontainers.image.version="${ODOO_VERSION}.0" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/taqat-techno/odoo-image" \
      org.opencontainers.image.vendor="TaqaTechno"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ODOO_VERSION=${ODOO_VERSION}

# ── Runtime system libraries (no -dev headers, no compilers) ──────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libxml2 \
    libxslt1.1 \
    libsasl2-2 \
    libjpeg62-turbo \
    libpng16-16 \
    libfreetype6 \
    fonts-noto-cjk \
    fonts-liberation \
    fontconfig \
    gettext \
    tzdata \
    rsync \
    curl \
    gnupg \
    ca-certificates \
 && if [ "$DEBIAN_CODENAME" = "bookworm" ]; then \
      apt-get install -y --no-install-recommends libldap-2.5-0 libwebp7; \
    else \
      apt-get install -y --no-install-recommends libldap-2.4-2 libwebp6; \
    fi \
 && rm -rf /var/lib/apt/lists/*

# ── wkhtmltopdf 0.12.6 ────────────────────────────────────────────────────────
RUN if [ "$DEBIAN_CODENAME" = "bookworm" ]; then \
      WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb"; \
    else \
      WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb"; \
    fi \
 && curl -fsSL -o /tmp/wkhtmltopdf.deb "$WKHTML_URL" \
 && apt-get update && apt-get install -y --no-install-recommends /tmp/wkhtmltopdf.deb \
 && rm /tmp/wkhtmltopdf.deb \
 && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 + rtlcss ───────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g rtlcss \
 && npm cache clean --force \
 && rm -rf /var/lib/apt/lists/*

# ── gosu for secure privilege dropping ────────────────────────────────────────
# Entrypoint starts as root to fix volume ownership, then drops to odoo user.
RUN apt-get update && apt-get install -y --no-install-recommends gosu \
 && rm -rf /var/lib/apt/lists/* \
 && gosu nobody true

# ── Copy compiled Python packages from builder ────────────────────────────────
COPY --from=builder /usr/local/lib/python${PYTHON_VERSION}/site-packages \
                    /usr/local/lib/python${PYTHON_VERSION}/site-packages

# ── setuptools<80 required: pkg_resources removed as standalone in 80+ ────────
RUN pip install --no-cache-dir "setuptools<80"

# ── Create odoo user and directories ──────────────────────────────────────────
RUN groupadd -g 1000 odoo \
 && useradd -u 1000 -g odoo -m -s /bin/bash odoo \
 && mkdir -p \
    /opt/odoo/source \
    /opt/odoo/custom-addons \
    /var/log/odoo \
    /var/lib/odoo/filestore \
    /etc/odoo \
 && chown -R odoo:odoo \
    /opt/odoo \
    /var/log/odoo \
    /var/lib/odoo \
    /etc/odoo

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# ── Runtime ───────────────────────────────────────────────────────────────────
# NOTE: No USER directive — entrypoint starts as root to fix volume ownership,
# then drops to odoo (UID 1000) via gosu before starting Odoo.
WORKDIR /opt/odoo

EXPOSE 8069 8072

VOLUME ["/opt/odoo/custom-addons", "/var/log/odoo", "/var/lib/odoo", "/etc/odoo"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -sf http://localhost:8069/web/health || curl -sf http://localhost:8069/web/login || exit 1

STOPSIGNAL SIGINT

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config=/etc/odoo/odoo.conf"]
