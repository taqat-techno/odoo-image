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

FROM python:${PYTHON_VERSION}-slim-${DEBIAN_CODENAME}

ARG ODOO_VERSION
ARG DEBIAN_CODENAME

LABEL maintainer="TaqaTechno <info@taqatechno.com>" \
      org.opencontainers.image.title="Odoo Enterprise ${ODOO_VERSION}" \
      org.opencontainers.image.source="https://github.com/taqat-techno/odoo-image" \
      org.opencontainers.image.vendor="TaqaTechno"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ODOO_VERSION=${ODOO_VERSION}

# ── System dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # PostgreSQL client library
    libpq-dev \
    # XML / XSLT (lxml)
    libxml2-dev \
    libxslt1-dev \
    # LDAP (python-ldap)
    libldap2-dev \
    libsasl2-dev \
    # SSL
    libssl-dev \
    # Image processing (Pillow)
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    libfreetype6-dev \
    # Fonts
    fonts-noto-cjk \
    fonts-liberation \
    fontconfig \
    # Misc
    gettext \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    xz-utils \
    # Required by python-ldap / gevent / libsass build
    gcc \
    g++ \
    make \
    python3-dev \
    libffi-dev \
 && rm -rf /var/lib/apt/lists/*

# ── wkhtmltopdf 0.12.6 (version matched to Debian release) ───────────────────
RUN if [ "$DEBIAN_CODENAME" = "bookworm" ]; then \
      WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb"; \
    else \
      WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb"; \
    fi \
 && wget -q -O /tmp/wkhtmltopdf.deb "$WKHTML_URL" \
 && apt-get update && apt-get install -y --no-install-recommends /tmp/wkhtmltopdf.deb \
 && rm /tmp/wkhtmltopdf.deb \
 && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 + rtlcss (for RTL/Arabic support) ──────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g rtlcss \
 && rm -rf /var/lib/apt/lists/*

# ── Python dependencies ────────────────────────────────────────────────────────
COPY requirements-*.txt /tmp/
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r /tmp/requirements-${ODOO_VERSION}.txt \
 && rm /tmp/requirements-*.txt

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
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Runtime ───────────────────────────────────────────────────────────────────
USER odoo
WORKDIR /opt/odoo

EXPOSE 8069 8072

VOLUME ["/opt/odoo/source", "/opt/odoo/custom-addons", "/var/log/odoo", "/var/lib/odoo/filestore", "/etc/odoo"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config=/etc/odoo/odoo.conf"]
