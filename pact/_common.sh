# shellcheck shell=bash
# Shared setup for the pact publishing / can-i-deploy scripts. Source this:
#   source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# Load pact/.env then pact/.env.local as DEFAULTS. Anything already set in the
# environment (shell export / CI secret) wins over the files — standard dotenv
# precedence. We snapshot the env-provided values and re-apply them after sourcing.
_pre_base_url="${PACT_BROKER_BASE_URL-}"
_pre_token="${PACT_BROKER_TOKEN-}"
for _envfile in "$HERE/.env" "$HERE/.env.local"; do
  if [[ -f "$_envfile" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$_envfile"
    set +a
  fi
done
[[ -n "$_pre_base_url" ]] && PACT_BROKER_BASE_URL="$_pre_base_url"
[[ -n "$_pre_token" ]]    && PACT_BROKER_TOKEN="$_pre_token"

# Broker URL + token are required for real runs (not for DRY_RUN shape checks).
if [[ "${DRY_RUN:-}" != "1" ]]; then
  : "${PACT_BROKER_BASE_URL:?set PACT_BROKER_BASE_URL (see pact/.env.example)}"
  : "${PACT_BROKER_TOKEN:?set PACT_BROKER_TOKEN (see pact/.env.example)}"
fi
export PACT_BROKER_BASE_URL="${PACT_BROKER_BASE_URL:-https://example.pactflow.io}"
export PACT_BROKER_TOKEN="${PACT_BROKER_TOKEN:-dry-run-token}"

GIT_SHA="${GIT_SHA:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)}"
GIT_BRANCH="${GIT_BRANCH:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
DEPLOY_ENVIRONMENT="${DEPLOY_ENVIRONMENT:-production}"
PACT_IMAGE="${PACT_IMAGE:-pactfoundation/pact:latest}"

# The two PactFlow pacticipants (each is both a provider and a consumer).
# These are the contract identities, distinct from the service directories
# (ruby-service = event-share-broker-service, ts-service = event-share-user-service).
PACTICIPANTS=(event-share-broker-service event-share-user-service)

# Run a command, or just print it under DRY_RUN=1.
_run() {
  if [[ "${DRY_RUN:-}" == "1" ]]; then
    printf 'DRY_RUN> %s\n' "$*"
  else
    "$@"
  fi
}

# A broker running on the HOST (e.g. a local PactFlow at localhost:9292) is not
# reachable as "localhost" from inside the CLI container — there localhost is the
# container itself. Rewrite loopback hosts to host.docker.internal (mapped below).
_container_broker_url() {
  printf '%s' "$PACT_BROKER_BASE_URL" \
    | sed -E 's#(^https?://)(localhost|127\.0\.0\.1)(:|/|$)#\1host.docker.internal\3#'
}

# The consolidated pact CLI (https://github.com/pact-foundation/pact-cli) via its
# Docker image, so nothing needs local install. It's a single `pact` binary (the
# image's default entrypoint) with `pactflow` and `broker` subcommands. The repo
# root is mounted at /work; credentials pass through the environment.
_pact_docker() {
  _run docker run --rm \
    --add-host host.docker.internal:host-gateway \
    -v "$ROOT:/work" -w /work \
    -e "PACT_BROKER_BASE_URL=$(_container_broker_url)" \
    -e PACT_BROKER_TOKEN \
    "$PACT_IMAGE" "$@"
}

pactflow_cli()   { _pact_docker pactflow "$@"; }
pactbroker_cli() { _pact_docker broker "$@"; }
