<p align="center">
  <img src="https://www.taqatechno.com/logo.png" alt="TaqaTechno" width="200"/>
</p>

<h1 align="center">alakosha/odoo-image</h1>

<p align="center">
  Pre-built Odoo Enterprise Docker base images &mdash; versions 14 through 19.<br/>
  Pull. Mount. Run.
</p>

<p align="center">
  <a href="https://hub.docker.com/r/alakosha/odoo-image"><img src="https://img.shields.io/badge/Docker%20Hub-alakosha%2Fodoo--image-2496ED?logo=docker&logoColor=white" alt="Docker Hub"/></a>
  <a href="https://github.com/taqat-techno/odoo-container"><img src="https://img.shields.io/badge/Odoo%20Source-taqat--techno%2Fodoo--container-blue" alt="Odoo Container"/></a>
</p>

---

## Quick Pull

```bash
docker pull alakosha/odoo-image:19.0
docker pull alakosha/odoo-image:18.0
docker pull alakosha/odoo-image:17.0
# ... and so on
```

---

## What's Inside

Each image contains:

- **Python** runtime (see version table)
- **All Odoo Python dependencies** pinned to the correct versions
- **wkhtmltopdf 0.12.6** for PDF report generation
- **Node.js 20 + rtlcss** for Arabic/RTL asset pipeline
- **Non-root `odoo` user** (UID 1000)
- **Smart entrypoint** — auto-detects Odoo version, supports dev mode and debugpy

The image does **not** contain the Odoo source code. Mount it from [taqat-techno/odoo-container](https://github.com/taqat-techno/odoo-container).

---

## Version Matrix

| Tag | Python | Odoo Source Branch |
|-----|--------|--------------------|
| `alakosha/odoo-image:19.0` | 3.12 | v19 |
| `alakosha/odoo-image:18.0` | 3.12 | v18 |
| `alakosha/odoo-image:17.0` | 3.12 | v17 |
| `alakosha/odoo-image:16.0` | 3.10 | v16 |
| `alakosha/odoo-image:15.0` | 3.10 | v15 |
| `alakosha/odoo-image:14.0` | 3.10 | v14 |

All images are built on **Debian Bookworm (slim)**.

---

## Usage with odoo-container

The intended workflow pairs this image with the [taqat-techno/odoo-container](https://github.com/taqat-techno/odoo-container) repo:

```bash
# 1. Clone the Odoo source (pick your version branch)
git clone -b v19 https://github.com/taqat-techno/odoo-container.git odoo19
cd odoo19

# 2. Clone your project modules
gh repo clone taqat-techno/my-project project-addons/my-project

# 3. Run /init-docker-container in Claude Code to auto-generate config
```

The `/init-docker-container` Claude command will:
- Detect the Odoo version from `odoo/release.py`
- Generate `conf/{project}.conf` and `docker-compose.{project}.yml`
- Pull the correct `alakosha/odoo-image:{version}.0` and start containers

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEV_MODE` | `0` | Set to `1` for `--dev=all` (auto-reload, debug assets) |
| `ENABLE_DEBUGGER` | `0` | Set to `1` for debugpy on port 5678 |

---

## Build Locally

```bash
# Build a specific version
docker build \
  --build-arg ODOO_VERSION=19 \
  --build-arg PYTHON_VERSION=3.12 \
  -t alakosha/odoo-image:19.0 \
  .
```

---

## CI/CD

Images are automatically built and pushed to Docker Hub via GitHub Actions on every push to `main`.

To trigger a manual build:
1. Go to **Actions** → **Build & Push Odoo Images**
2. Click **Run workflow**
3. Optionally specify a single version (e.g. `19`) or leave empty for all

### Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | `alakosha` |
| `DOCKERHUB_TOKEN` | Docker Hub access token (Read & Write) |

---

<p align="center">
  Maintained by <a href="https://www.taqatechno.com/">TaqaTechno</a>
</p>
