#!/usr/bin/env bash
# Best-effort: add `<minikube-ip>  pets.local` to /etc/hosts so a reviewer
# can do `curl http://pets.local/cats` without --resolve.
#
# Requires sudo. If the user declines, we just print the --resolve form.
#
# Usage:  bash minikube/scripts/_etc_hosts.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

IP="$(minikube ip)"
LINE="${IP}\t${HOSTNAME}\t# minikube pet-system"

if grep -qE "[[:space:]]${HOSTNAME}([[:space:]]|$)" /etc/hosts; then
  EXISTING_IP="$(awk -v h="${HOSTNAME}" '$2==h{print $1}' /etc/hosts | head -1)"
  if [[ "${EXISTING_IP}" == "${IP}" ]]; then
    log "/etc/hosts already maps ${HOSTNAME} → ${IP}"
    exit 0
  fi
  warn "/etc/hosts has ${HOSTNAME} mapped to a different IP (${EXISTING_IP}); leaving it alone."
  warn "fall back to: curl --resolve ${HOSTNAME}:80:${IP} http://${HOSTNAME}/cats"
  exit 0
fi

log "adding ${HOSTNAME} → ${IP} to /etc/hosts (sudo required)"
if printf '%b\n' "${LINE}" | sudo tee -a /etc/hosts >/dev/null; then
  log "/etc/hosts updated"
else
  warn "could not update /etc/hosts; fall back to:"
  warn "  curl --resolve ${HOSTNAME}:80:${IP} http://${HOSTNAME}/cats"
fi
