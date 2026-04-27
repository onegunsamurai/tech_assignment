#!/usr/bin/env bash
# Bring up a local kind cluster, build local images, and install the umbrella
# chart. Useful for offline development without AWS.
set -euo pipefail

CLUSTER=${CLUSTER:-pet-mgmt}
NAMESPACE=${NAMESPACE:-pet-system}
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

# Build images locally and load them straight into the kind nodes — avoids
# pushing to a registry for development.
docker build -t pet-operator:dev -f "$REPO_ROOT/operator/Dockerfile" "$REPO_ROOT/operator"
docker build -t pet-api:dev      -f "$REPO_ROOT/api/Dockerfile"      "$REPO_ROOT"

kind load docker-image pet-operator:dev pet-api:dev --name "$CLUSTER"

helm upgrade --install pet-system "$REPO_ROOT/charts/pet-system" \
  --namespace "$NAMESPACE" --create-namespace \
  --set pet-operator.image.repository=pet-operator \
  --set pet-operator.image.tag=dev \
  --set pet-operator.image.pullPolicy=IfNotPresent \
  --set pet-api.image.repository=pet-api \
  --set pet-api.image.tag=dev \
  --set pet-api.image.pullPolicy=IfNotPresent \
  --set pet-api.ingress.enabled=false

echo
echo "Apply sample pets with:"
echo "  kubectl apply -f $REPO_ROOT/manifests/sample-pets/"
echo
echo "Watch state with:"
echo "  watch kubectl get cats,dogs -n $NAMESPACE"
