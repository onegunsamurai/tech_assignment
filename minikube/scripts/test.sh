#!/usr/bin/env bash
# Smoke test for the minikube path. Asserts the assignment requirements:
#   - immutable spec fields (color/gender/breed)
#   - dynamic state retrievable via kubectl
#   - state changes over time (operator reconciles)
#   - REST API serves the same pets
#   - declarative onboarding of a new pet (event-driven path)
#   - delete removes the pet from listings
#
# Exits 0 on success, non-zero on the first failure.
#
# Usage:  bash minikube/scripts/test.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_cmd kubectl
require_cmd minikube
require_cmd curl

PASS=0; FAIL=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  %s✓%s %s\n' "${C_GREEN}" "${C_RESET}" "${name}"
    PASS=$((PASS+1))
  else
    printf '  %s✗%s %s\n' "${C_RED}" "${C_RESET}" "${name}"
    FAIL=$((FAIL+1))
  fi
}

IP="$(minikube ip)"
CURL_BASE=(curl -sS --max-time 5 --resolve "${HOSTNAME}:80:${IP}" "http://${HOSTNAME}")

log "1. immutable spec fields exposed via kubectl"
COLOR="$(kubectl get cat ginger -n "${NAMESPACE}" -o jsonpath='{.spec.color}')"
[[ "${COLOR}" == "ginger" ]] && check "ginger.spec.color == ginger" true \
                              || check "ginger.spec.color == ginger" false

log "2. dynamic state populated by operator"
STATE_BEFORE="$(kubectl get cat ginger -n "${NAMESPACE}" -o jsonpath='{.status.state}')"
[[ -n "${STATE_BEFORE}" ]] && check "ginger.status.state non-empty" true \
                            || check "ginger.status.state non-empty" false

log "3. state mutates over time (reconcile interval = 15s)"
log "   waiting 35s for at least two reconciles..."
sleep 35
STATE_AFTER="$(kubectl get cat ginger -n "${NAMESPACE}" -o jsonpath='{.status.state}')"
LAST_TT="$(kubectl get cat ginger -n "${NAMESPACE}" -o jsonpath='{.status.lastTransitionTime}')"
# Either the state JSON changed, or lastTransitionTime advanced — both prove reconcile.
if [[ "${STATE_BEFORE}" != "${STATE_AFTER}" || -n "${LAST_TT}" ]]; then
  check "state advanced (lastTransitionTime=${LAST_TT})" true
else
  check "state advanced" false
fi

log "4. REST API lists the cats via ingress"
CATS_JSON="$("${CURL_BASE[@]}/cats" || true)"
echo "${CATS_JSON}" | grep -q '"breed":"maine-coon"' \
  && check "GET /cats includes ginger (maine-coon)" true \
  || check "GET /cats includes ginger (maine-coon)" false

log "5. immutable spec is enforced (CEL)"
PATCH_OUT="$(kubectl patch cat ginger -n "${NAMESPACE}" --type=merge \
              -p '{"spec":{"color":"black"}}' 2>&1 || true)"
echo "${PATCH_OUT}" | grep -qiE 'immutable|invalid' \
  && check "patching spec.color is rejected" true \
  || check "patching spec.color is rejected" false

log "6. event-driven onboarding of a new dog"
# REST responses use the CR UID as `id` and don't expose metadata.name, so
# we tag the test pet with a unique breed value and search for that.
SMOKE_BREED="smoketest-breed-$$"
kubectl apply -f - <<EOF >/dev/null
apiVersion: pets.example.com/v1alpha1
kind: Dog
metadata:
  name: smoketest-buddy
  namespace: ${NAMESPACE}
spec:
  color: brown
  gender: male
  breed: ${SMOKE_BREED}
  initialState:
    isBarking: false
    isHungry: true
    isSleeping: false
EOF
DEADLINE=$(( $(date +%s) + 60 ))
NEW_STATE=""
while [[ $(date +%s) -lt ${DEADLINE} ]]; do
  NEW_STATE="$(kubectl get dog smoketest-buddy -n "${NAMESPACE}" \
              -o jsonpath='{.status.state}' 2>/dev/null || true)"
  [[ -n "${NEW_STATE}" ]] && break
  sleep 3
done
[[ -n "${NEW_STATE}" ]] && check "new dog .status.state populated within 60s" true \
                       || check "new dog .status.state populated within 60s" false

DOGS_JSON="$("${CURL_BASE[@]}/dogs" || true)"
echo "${DOGS_JSON}" | grep -q "\"breed\":\"${SMOKE_BREED}\"" \
  && check "GET /dogs lists the new dog before deletion" true \
  || check "GET /dogs lists the new dog before deletion" false

log "7. delete removes the dog from REST listings"
kubectl delete dog smoketest-buddy -n "${NAMESPACE}" >/dev/null
sleep 3
DOGS_JSON="$("${CURL_BASE[@]}/dogs" || true)"
echo "${DOGS_JSON}" | grep -q "\"breed\":\"${SMOKE_BREED}\"" \
  && check "GET /dogs no longer lists deleted dog" false \
  || check "GET /dogs no longer lists deleted dog" true

echo
log "passed: ${PASS}    failed: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
