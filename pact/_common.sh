# shellcheck shell=bash
# Shared setup for the pact publishing / can-i-deploy scripts. Source this:
#   source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# Load pact/.env if present (export everything it defines).
if [[ -f "$HERE/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$HERE/.env"
  set +a
fi

# Credentials are required for real runs, but not for DRY_RUN shape checks.
if [[ "${DRY_RUN:-}" != "1" ]]; then
  : "${PACT_BROKER_BASE_URL:?set PACT_BROKER_BASE_URL (see pact/.env.example)}"
  : "${PACT_BROKER_TOKEN:?set PACT_BROKER_TOKEN (see pact/.env.example)}"
fi
export PACT_BROKER_BASE_URL="${PACT_BROKER_BASE_URL:-https://example.pactflow.io}"
export PACT_BROKER_TOKEN="${PACT_BROKER_TOKEN:-dry-run-token}"

GIT_SHA="${GIT_SHA:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)}"
GIT_BRANCH="${GIT_BRANCH:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
DEPLOY_ENVIRONMENT="${DEPLOY_ENVIRONMENT:-production}"
PACT_IMAGE="${PACT_IMAGE:-pactfoundation/pact-cli:latest}"

# The two pacticipants (each is both a provider and a consumer).
PACTICIPANTS=(ruby-service ts-service)

# Run a command, or just print it under DRY_RUN=1.
_run() {
  if [[ "${DRY_RUN:-}" == "1" ]]; then
    printf 'DRY_RUN> %s\n' "$*"
  else
    "$@"
  fi
}

# pact CLIs via the pact-foundation Docker image, so nothing needs local install.
# The repo root is mounted at /work; credentials are passed through the environment.
_pact_docker() {
  local entrypoint="$1"; shift
  _run docker run --rm \
    -v "$ROOT:/work" -w /work \
    -e PACT_BROKER_BASE_URL -e PACT_BROKER_TOKEN \
    --entrypoint "$entrypoint" "$PACT_IMAGE" "$@"
}

pactflow_cli()    { _pact_docker pactflow "$@"; }
pactbroker_cli()  { _pact_docker pact-broker "$@"; }
