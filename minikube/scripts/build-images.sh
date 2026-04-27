#!/usr/bin/env bash
# Builds the API and operator images and loads them into the minikube
# container runtime.
#
# Why `docker build` + `minikube image load` instead of `minikube image
# build`: with the docker driver, `minikube image build` runs the build
# inside the minikube container, which cannot see /Users (the host's home
# tree). It fails with "lstat /Users: no such file or directory". Building
# on the host and then `image load`-ing into minikube avoids that.
#
# Usage:  bash minikube/scripts/build-images.sh
#
# Idempotent. Re-running rebuilds and replaces the :local tag.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_cmd docker
require_cmd minikube
require_cmd go

# The committed repo lacks go.sum files for both modules, so the
# Dockerfile's `go mod download || true` falls through and the subsequent
# `go build` fails with "missing go.sum entry" errors. Tidy the modules on
# the host first — this regenerates the missing go.sum files (which are
# generated artifacts) without touching any go source. Idempotent.
log "tidying go modules (operator → api)"
( cd "${REPO_ROOT}/operator" && go mod tidy )
( cd "${REPO_ROOT}/api"      && go mod tidy )

# The API Dockerfile copies operator/ into its build context (see
# api/Dockerfile:8 — needed for the go.mod replace directive). So the API
# build must run from the repo root, not from api/.
log "building pet-api:local on the host (context: repo root)"
docker build \
  -t pet-api:local \
  -f "${REPO_ROOT}/api/Dockerfile" \
  "${REPO_ROOT}"

log "building pet-operator:local on the host (context: operator/)"
docker build \
  -t pet-operator:local \
  -f "${REPO_ROOT}/operator/Dockerfile" \
  "${REPO_ROOT}/operator"

log "loading images into minikube"
minikube image load pet-api:local
minikube image load pet-operator:local

log "verifying images are present in the minikube runtime"
LISTING="$(minikube image ls)"
for img in pet-api:local pet-operator:local; do
  if echo "${LISTING}" | grep -qE "(^|/)${img}\$"; then
    printf '  %s✓%s %s\n' "${C_GREEN}" "${C_RESET}" "${img}" >&2
  else
    die "image ${img} not present in minikube after load"
  fi
done
