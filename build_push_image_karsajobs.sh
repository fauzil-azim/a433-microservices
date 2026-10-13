#!/usr/bin/env bash

set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-fauzil-docker/karsajobs}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
REGISTRY_USER="${REGISTRY_USER:-${GITHUB_ACTOR:-}}"
: "${REGISTRY_TOKEN:?REGISTRY_TOKEN is required (token with write:packages)}"
: "${REGISTRY_USER:?REGISTRY_USER (or GITHUB_ACTOR) is required}"

# Registry paths must be lowercase, but GitHub usernames can contain capitals
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

OWNER="$(lower "${GITHUB_REPOSITORY_OWNER:-$REGISTRY_USER}")"
SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
SHORT_SHA="${SHA:0:7}"
IMAGE="${REGISTRY}/${OWNER}/${IMAGE_NAME}"

echo ">> Image: ${IMAGE}  (tags: ${SHORT_SHA}, latest)"

echo ">> Logging in to ${REGISTRY} as ${REGISTRY_USER}"
printf '%s' "$REGISTRY_TOKEN" | docker login "$REGISTRY" --username "$REGISTRY_USER" --password-stdin
trap 'docker logout "$REGISTRY" >/dev/null 2>&1 || true' EXIT

args=(
  --file "$DOCKERFILE"
  --tag "${IMAGE}:${SHORT_SHA}"
  --tag "${IMAGE}:latest"
  --label "org.opencontainers.image.revision=${SHA}"
  --provenance=false # keeps the GHCR package page free of extra "unknown/unknown" entries
  --push
)

# Links the package to the repository on GitHub (visibility/permissions inherit from the repo)
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  args+=(--label "org.opencontainers.image.source=https://github.com/${GITHUB_REPOSITORY}")
fi

echo ">> Building and pushing"
docker buildx build "${args[@]}" .