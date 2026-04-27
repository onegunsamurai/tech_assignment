# Sourced by every script in this directory. Provides repo-root discovery,
# colored logging, and prereq checking. Not executable on its own.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MINIKUBE_DIR="${REPO_ROOT}/minikube"
NAMESPACE="pet-system"
RELEASE="pet-system"
HOSTNAME="pets.local"

if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

log()  { printf '%s==>%s %s\n' "${C_GREEN}" "${C_RESET}" "$*" >&2; }
warn() { printf '%s!! %s%s\n'   "${C_YELLOW}" "$*" "${C_RESET}" >&2; }
die()  { printf '%s!! %s%s\n'   "${C_RED}"    "$*" "${C_RESET}" >&2; exit 1; }

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || die "missing prerequisite: ${cmd}"
}

require_prereqs() {
  for c in minikube kubectl helm docker; do
    require_cmd "${c}"
  done
}
