#!/usr/bin/env bash
# Publish the AsyncAPI provider contract for BOTH pacticipants to PactFlow, each
# with its self-verification results attached (the messaging equivalent of BDCT's
# provider verification). AsyncAPI provider contracts are a PactFlow pilot
# capability, published with `--specification asyncapi`.
#
# Env-driven — see pact/.env.example. Run with DRY_RUN=1 to print the commands.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

publish_provider() {
  local provider="$1" verify_cmd="$2"
  # Written under $ROOT (mounted at /work) so the CLI container can read it.
  local results_rel="pact/.verification-${provider}.txt"
  local results_abs="${ROOT}/${results_rel}"

  echo "== $provider: self-verify publisher against asyncapi.yaml =="
  local code=0
  if [[ "${DRY_RUN:-}" == "1" ]]; then
    printf 'DRY_RUN> %s\n' "$verify_cmd"
    printf 'self-verification output (dry run)\n' > "$results_abs"
  else
    ( cd "$ROOT" && eval "$verify_cmd" ) > "$results_abs" 2>&1 || code=$?
    cat "$results_abs"
  fi

  echo "== $provider: publish AsyncAPI provider contract (verification exit code = $code) =="
  pactflow_cli publish-provider-contract \
    asyncapi.yaml \
    --provider "$provider" \
    --provider-app-version "$GIT_SHA" \
    --branch "$GIT_BRANCH" \
    --specification asyncapi \
    --content-type application/yaml \
    --verifier asyncapi-self-verification \
    --verification-exit-code "$code" \
    --verification-results "$results_rel" \
    --verification-results-content-type text/plain \
    --verification-results-format text

  rm -f "$results_abs"
  echo
}

publish_provider event-share-broker-service "(cd ruby-service && ruby bin/verify_provider_contract.rb)"
publish_provider event-share-user-service   "(cd ts-service && npm run --silent verify:provider)"

echo "Provider contracts published for: ${PACTICIPANTS[*]}"
