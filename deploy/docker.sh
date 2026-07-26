#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Chatwoot Release Script
#
# Builds the production Docker image and pushes it to
# Hamravesh Docker Registry.
#
# Usage:
#   ./deploy/build.sh
# ============================================================

REGISTRY="registry.hamdocker.ir"
PROJECT="raghamapp"
IMAGE="chatwoot"

TAG=$(date +"%Y-%m-%d_%H-%M")
FULL_IMAGE="${REGISTRY}/${PROJECT}/${IMAGE}:${TAG}"

echo "=================================================="
echo " Chatwoot Release"
echo "=================================================="
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
echo "Building Docker image..."
echo

docker build \
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

docker push "${FULL_IMAGE}"

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
