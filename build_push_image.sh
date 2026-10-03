#!/usr/bin/env bash
# Build the Docker image and push it to GitHub Packages (GitHub Container Registry).
#
# Required environment variables (never hardcode the token in this file):
#   GITHUB_USERNAME  GitHub username (any case; converted to lowercase)
#   GITHUB_TOKEN     Personal Access Token (classic) with the `write:packages` scope
#
# Usage:
#   export GITHUB_USERNAME=username
#   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
#   ./build_push_image.sh

# Enable strict error handling
set -euo pipefail

# Check if .env file exists and load it
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "Warning: .env file not found. Relying on existing system variables."
fi

# Enforce validation (script will crash here if variables are missing)
: "${GITHUB_USERNAME:?Set GITHUB_USERNAME first}"
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN first (PAT with write:packages)}"

IMAGE_NAME="${IMAGE_NAME:-item-app}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
# GitHub Packages requires the owner and image name to be lowercase.
OWNER="$(echo "$GITHUB_USERNAME" | tr '[:upper:]' '[:lower:]')"
REMOTE_IMAGE="ghcr.io/${OWNER}/${IMAGE_NAME}:${IMAGE_TAG}"

# Check if the first argument ($1) matches "--debug"
if [ "${1:-}" = "--debug" ]; then
    echo "Variables verified successfully for GITHUB_USERNAME=$GITHUB_USERNAME"
    echo "Variables verified successfully for GITHUB_TOKEN=$GITHUB_TOKEN"
    echo "Variables verified successfully for REMOTE_IMAGE=${REMOTE_IMAGE}"
    exit
fi

# 1. Build the image from the Dockerfile in the current directory
#    (no --target given, so the final `runtime` stage = production image).
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

# 2. List local images to confirm the build
docker images

# 3. Rename (tag) the image to the format GitHub Packages requires:
#    ghcr.io/<username>/<image>:<tag>
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REMOTE_IMAGE}"

# 4. Log in to GitHub Packages. The token is piped via stdin so it does not
#    appear in the process list or shell history.
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u "${GITHUB_USERNAME}" --password-stdin

# 5. Push the image to GitHub Packages
docker push "${REMOTE_IMAGE}"