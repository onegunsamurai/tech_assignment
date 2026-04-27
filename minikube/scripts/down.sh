#!/usr/bin/env bash
# Tear down the pet-system release. By default leaves minikube running
# (re-running up.sh is then very fast). Pass --delete-cluster to also
# `minikube delete`.
#
# Usage:
#   bash minikube/scripts/down.sh
#   bash minikube/scripts/down.sh --delete-cluster

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

DELETE_CLUSTER=0
for arg in "$@"; do
  case "${arg}" in
    --delete-cluster) DELETE_CLUSTER=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) die "unknown argument: ${arg}" ;;
  esac
done

require_cmd kubectl
require_cmd helm

if helm status "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  log "uninstalling helm release ${RELEASE}"
  helm uninstall "${RELEASE}" -n "${NAMESPACE}"
else
  log "helm release ${RELEASE} not found — skipping"
fi

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  log "deleting namespace ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}" --wait=false
fi

# CRDs are cluster-scoped and remain after release uninstall. Remove them
# so a subsequent `up.sh` starts from a clean slate.
log "deleting Cat / Dog CRDs"
kubectl delete crd cats.pets.example.com dogs.pets.example.com --ignore-not-found=true

if [[ "${DELETE_CLUSTER}" == "1" ]]; then
  require_cmd minikube
  log "deleting the minikube cluster"
  minikube delete
fi

log "done"
