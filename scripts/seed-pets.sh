#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=${NAMESPACE:-pet-system}
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/manifests/sample-pets/"
