#!/usr/bin/env bash
# Publish the AsyncAPI provider contract for BOTH pacticipants to PactFlow,
# each with its provider self-verification result attached (BDCT for AsyncAPI).
#
# Env-driven — see pact/.env.example. Run with DRY_RUN=1 to print the commands.
#
# PILOT NOTE: AsyncAPI provider contracts are a PactFlow *pilot*. The contract is
# published with `--specification asyncapi` (+ `--content-type application/yaml`).
# Adjust if the pilot differs.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# provider name + the command that self-verifies it (exit code feeds the publish).
publish_provider() {
  local provider="$1" verify_cmd="$2"

  echo "== $provider: self-verify publisher against asyncapi.yaml =="
  local code=0
  if [[ "${DRY_RUN:-}" == "1" ]]; then
    printf 'DRY_RUN> %s\n' "$verify_cmd"
  else
    ( cd "$ROOT" && eval "$verify_cmd" ) || code=$?
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
    --verification-exit-code "$code"
  echo
}

publish_provider ruby-service "(cd ruby-service && ruby bin/verify_provider_contract.rb)"
publish_provider ts-service   "(cd ts-service && npm run --silent verify:provider)"

echo "Provider contracts published for: ${PACTICIPANTS[*]}"
