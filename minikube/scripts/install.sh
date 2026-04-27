#!/usr/bin/env bash
# Installs / upgrades the pet-system umbrella chart with the minikube
# values override. Safe to run repeatedly — `helm upgrade --install` is
# idempotent.
#
# Usage:  bash minikube/scripts/install.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_cmd helm
require_cmd kubectl

CHART_DIR="${REPO_ROOT}/charts/pet-system"
VALUES_FILE="${MINIKUBE_DIR}/values/minikube-values.yaml"

[[ -f "${VALUES_FILE}" ]] || die "missing values file: ${VALUES_FILE}"

log "resolving subchart dependencies"
helm dependency update "${CHART_DIR}" >/dev/null

log "ensuring namespace ${NAMESPACE} exists"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

log "installing chart ${RELEASE} from ${CHART_DIR}"
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait --timeout 5m

log "rollout status"
kubectl -n "${NAMESPACE}" rollout status deployment --timeout=2m
