#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Chatwoot Release Script
#
# Builds the production image and pushes it to Hamravesh Docker
# Registry, with Docker when it is installed and Podman otherwise.
# With Podman, log in once first: podman login registry.hamdocker.ir
#
# Usage:
#   bash deploy/release.sh
# ============================================================

REGISTRY="registry.hamdocker.ir"
PROJECT="raghamapp"
IMAGE="chatwoot"

TAG=$(date +"%Y-%m-%d_%H-%M")
FULL_IMAGE="${REGISTRY}/${PROJECT}/${IMAGE}:${TAG}"

# Podman writes OCI manifests by default; `--format docker` makes it produce
# the same Docker manifest a Docker build would, so the platform pulls an image
# identical in kind whichever engine built it.
if command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
    BUILD_FLAGS=()
elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
    BUILD_FLAGS=(--format docker)
else
    echo "ERROR: Neither docker nor podman is installed."
    exit 1
fi

echo "=================================================="
echo " Chatwoot Release"
echo "=================================================="
echo "Engine: ${ENGINE}"
echo "Image : ${FULL_IMAGE}"
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git rev-parse --short HEAD)"
echo

# ------------------------------------------------------------
# Ensure repository is clean
# ------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Repository contains uncommitted changes."
    echo
    git status --short
    exit 1
fi

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------
echo "Building image..."
echo

"${ENGINE}" build \
    "${BUILD_FLAGS[@]}" \
    -t "${FULL_IMAGE}" \
    -f docker/Dockerfile \
    .

echo
echo "Build completed."

# ------------------------------------------------------------
# Push
# ------------------------------------------------------------
echo
echo "Pushing image to registry..."
echo

"${ENGINE}" push "${FULL_IMAGE}"

echo
echo "=================================================="
echo " Release completed successfully!"
echo "=================================================="
echo
echo "Image:"
echo "  ${FULL_IMAGE}"
echo
echo "Update docker-compose.production.yaml:"
echo
echo "image: ${FULL_IMAGE}"
echo
