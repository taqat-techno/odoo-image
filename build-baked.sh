#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Build an Odoo image with source baked in (zero I/O overhead)
#
# Usage:
#   ./build-baked.sh <version> <source-dir>
#   ./build-baked.sh 19 ../odoo-19
#   ./build-baked.sh 17 ../odoo-17
# ──────────────────────────────────────────────────────────────────────────────
set -e

ODOO_VERSION="${1:?Usage: $0 <version> <source-dir>}"
SOURCE_DIR="${2:?Usage: $0 <version> <source-dir>}"
TAG="alakosha/odoo-image:${ODOO_VERSION}.0-baked"

echo "Building baked image: ${TAG}"
echo "Source directory:     ${SOURCE_DIR}"

docker build \
  -f Dockerfile.baked \
  --build-arg ODOO_VERSION="${ODOO_VERSION}" \
  --build-arg SOURCE_DIR="${SOURCE_DIR}" \
  -t "${TAG}" \
  .

echo ""
echo "Done! Image: ${TAG}"
echo "Use in docker-compose: image: ${TAG}"
echo "No source bind mount needed — source is baked into the image."
