#!/usr/bin/env bash
# End-to-end bootstrap of the assignment on minikube.
#
#   1. start minikube (if it isn't running)
#   2. enable the ingress addon
#   3. build pet-api + pet-operator images into the minikube runtime
#   4. helm install the umbrella chart with the minikube values override
#   5. apply the sample pets (rex, ginger)
#   6. (optional) add pets.local to /etc/hosts
#
# Idempotent. Safe to re-run.
#
# Usage:  bash minikube/scripts/up.sh [--skip-hosts]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

SKIP_HOSTS="${SKIP_HOSTS:-0}"
for arg in "$@"; do
  case "${arg}" in
    --skip-hosts) SKIP_HOSTS=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) die "unknown argument: ${arg}" ;;
  esac
done

require_prereqs

# 1. cluster
if ! minikube status --format='{{.Host}}' 2>/dev/null | grep -q Running; then
  log "starting minikube (cpus=2, memory=2048MB, driver=docker)"
  minikube start --cpus=2 --memory=2048 --driver=docker
else
  log "minikube already running"
fi

# 2. ingress addon
if minikube addons list -o json | grep -q '"ingress"[^}]*"Status": "enabled"'; then
  log "ingress addon already enabled"
else
  log "enabling ingress addon (may take ~30s)"
  minikube addons enable ingress
fi

# 3. images
bash "${SCRIPT_DIR}/build-images.sh"

# 4. helm
bash "${SCRIPT_DIR}/install.sh"

# 5. samples
log "applying sample pets (rex, ginger) into ${NAMESPACE}"
kubectl apply -n "${NAMESPACE}" -f "${REPO_ROOT}/manifests/sample-pets/"

# 6. /etc/hosts
if [[ "${SKIP_HOSTS}" == "0" ]]; then
  bash "${SCRIPT_DIR}/_etc_hosts.sh" || true
else
  log "skipping /etc/hosts edit (--skip-hosts set)"
fi

cat <<EOF

✓ pet-system is up.

Try:
  kubectl get cats,dogs -n ${NAMESPACE}
  watch -n2 kubectl get cat ginger -n ${NAMESPACE}

  # via ingress (after /etc/hosts entry, or with --resolve):
  curl http://${HOSTNAME}/cats
  curl --resolve ${HOSTNAME}:80:\$(minikube ip) http://${HOSTNAME}/cats

  # automated smoke test:
  bash minikube/scripts/test.sh

  # teardown:
  bash minikube/scripts/down.sh
EOF
