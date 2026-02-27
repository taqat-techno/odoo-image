<p align="center">
  <img src="https://www.taqatechno.com/logo.png" alt="TaqaTechno" width="180"/>
</p>

<h1 align="center">alakosha/odoo-image</h1>

<p align="center">
  Pre-built Odoo Enterprise base images — versions 14 through 19.<br/>
  No source included. Pull, mount your source, run.
</p>

<p align="center">
  <a href="https://hub.docker.com/r/alakosha/odoo-image"><img src="https://img.shields.io/badge/Docker%20Hub-alakosha%2Fodoo--image-2496ED?logo=docker&logoColor=white" alt="Docker Hub"/></a>
  <a href="https://github.com/taqat-techno/odoo-image"><img src="https://img.shields.io/badge/GitHub-taqat--techno%2Fodoo--image-181717?logo=github" alt="GitHub"/></a>
  <a href="https://github.com/taqat-techno/odoo-container"><img src="https://img.shields.io/badge/Odoo%20Source-taqat--techno%2Fodoo--container-blue" alt="Odoo Container"/></a>
</p>

---

## Supported Tags

| Tag | Alias | Python | Debian | Odoo Branch |
|-----|-------|--------|--------|-------------|
| `19.0` | **`latest`** | 3.12 | Bookworm | v19 |
| `18.0` | — | 3.12 | Bookworm | v18 |
| `17.0` | — | 3.12 | Bookworm | v17 |
| `16.0` | — | 3.10 | Bullseye | v16 |
| `15.0` | — | 3.8 | Bullseye | v15 |
| `14.0` | — | 3.8 | Bullseye | v14 |

```bash
docker pull alakosha/odoo-image:latest    # Odoo 19 (recommended)
docker pull alakosha/odoo-image:19.0
docker pull alakosha/odoo-image:18.0
docker pull alakosha/odoo-image:17.0
docker pull alakosha/odoo-image:16.0
docker pull alakosha/odoo-image:15.0
docker pull alakosha/odoo-image:14.0
```

---

## What's Inside

Every image ships with everything Odoo needs to run — **except the source code**, which you mount at runtime:

| Component | Version | Purpose |
|-----------|---------|---------|
| Python | 3.8 / 3.10 / 3.12 | Runtime |
| All Odoo Python deps | pinned per version | `psycopg2`, `lxml`, `Pillow`, `gevent`, … |
| **wkhtmltopdf** | 0.12.6.1 (patched Qt) | PDF report generation |
| **Node.js** | 20 LTS | Asset pipeline |
| **rtlcss** | latest | Arabic / RTL CSS support |
| Noto CJK fonts | — | Arabic, CJK rendering in PDFs |
| Liberation fonts | — | PDF default fonts |
| `odoo` user | UID 1000 | Non-root runtime |

---

## Quick Start

```bash
# Pull the image
docker pull alakosha/odoo-image:19.0

# Run with Odoo source mounted
docker run -d \
  --name odoo19 \
  -p 8069:8069 \
  -v /path/to/odoo-source:/opt/odoo/source:ro \
  -v /path/to/custom-addons:/opt/odoo/custom-addons:ro \
  -v /path/to/odoo.conf:/etc/odoo/odoo.conf:ro \
  alakosha/odoo-image:19.0
```

> **Odoo source not included.** Clone it from [taqat-techno/odoo-container](https://github.com/taqat-techno/odoo-container) and mount it.

---

## Volume Mounts

| Path | Purpose |
|------|---------|
| `/opt/odoo/source` | **Required** — Odoo source code |
| `/opt/odoo/custom-addons` | Custom / project modules |
| `/etc/odoo/odoo.conf` | Odoo configuration file |
| `/var/log/odoo` | Log files |
| `/var/lib/odoo/filestore` | Uploaded attachments & filestore |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEV_MODE` | `0` | Set to `1` → adds `--dev=all` (auto-reload, debug assets) |
| `ENABLE_DEBUGGER` | `0` | Set to `1` → starts debugpy on port `5678`, waits for client |

```bash
# Development mode with live reload
docker run -e DEV_MODE=1 alakosha/odoo-image:19.0

# Remote debugging (VS Code / PyCharm)
docker run -e ENABLE_DEBUGGER=1 -p 5678:5678 alakosha/odoo-image:19.0
```

---

## Exposed Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `8069` | HTTP | Odoo web interface |
| `8072` | HTTP | Odoo long-polling (live chat, bus) |

---

## Usage with odoo-container

The recommended workflow pairs this image with [taqat-techno/odoo-container](https://github.com/taqat-techno/odoo-container):

```bash
# Clone the Odoo source for your version
git clone -b v19 https://github.com/taqat-techno/odoo-container.git odoo19
cd odoo19

# Clone your project modules
gh repo clone taqat-techno/my-project project-addons/my-project

# Run /init-docker-container in Claude Code to auto-generate config
```

The `/init-docker-container` skill auto-detects the Odoo version, generates `docker-compose.yml` and `odoo.conf`, pulls the correct image, and starts the stack.

---

## Build Locally

```bash
docker build \
  --build-arg ODOO_VERSION=19 \
  --build-arg PYTHON_VERSION=3.12 \
  --build-arg DEBIAN_CODENAME=bookworm \
  -t alakosha/odoo-image:19.0 \
  https://github.com/taqat-techno/odoo-image.git
```

---

## License

Images are provided as-is for use with Odoo Enterprise.
Odoo is a trademark of [Odoo S.A.](https://www.odoo.com/)

---

<p align="center">
  Maintained by <a href="https://www.taqatechno.com/">TaqaTechno</a>
</p>
