#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Chatwoot Staging Release Script
#
# Builds the image and pushes it to Hamravesh Docker Registry as
# chatwoot-stage, kept apart from the production chatwoot image.
# Unlike deploy/release.sh it builds uncommitted changes too; the
# tag then ends in -dirty so the image is never mistaken for a commit.
# With Podman, log in once first: podman login registry.hamdocker.ir
#
# Usage:
#   bash deploy/release-stage.sh
# ============================================================

REGISTRY="registry.hamdocker.ir"
PROJECT="raghamapp"
IMAGE="chatwoot-stage"

COMMIT=$(git rev-parse --short HEAD)
DIRTY=""
if [[ -n "$(git status --porcelain)" ]]; then
    DIRTY="-dirty"
fi

TAG="$(date +"%Y-%m-%d_%H-%M")_${COMMIT}${DIRTY}"
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
echo " Chatwoot Staging Release"
echo "=================================================="
echo "Engine: ${ENGINE}"
echo "Image : ${FULL_IMAGE}"
echo "Branch: $(git branch --show-current)"
echo "Commit: ${COMMIT}"
echo

if [[ -n "${DIRTY}" ]]; then
    echo "WARNING: Building uncommitted changes. This image matches no commit:"
    echo
    git status --short
    echo
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
echo " Staging release completed successfully!"
echo "=================================================="
echo
echo "Image:"
echo "  ${FULL_IMAGE}"
echo
echo "Set it on the staging app and sidekiq pods:"
echo
echo "image: ${FULL_IMAGE}"
echo
