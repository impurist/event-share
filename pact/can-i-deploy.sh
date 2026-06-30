#!/usr/bin/env bash
# can-i-deploy for each pacticipant. PactFlow runs cross-contract validation
# (consumer message pact ⊆ AsyncAPI provider contract) plus checks the provider
# self-verification — and answers whether this version is safe to deploy.
#
# Env-driven — see pact/.env.example. Run with DRY_RUN=1 to print the commands.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

for participant in "${PACTICIPANTS[@]}"; do
  echo "== can-i-deploy: $participant @ $GIT_SHA → $DEPLOY_ENVIRONMENT =="
  pactbroker_cli can-i-deploy \
    --pacticipant "$participant" \
    --version "$GIT_SHA" \
    --to-environment "$DEPLOY_ENVIRONMENT" \
    --retry-while-unknown 6 \
    --retry-interval 10
  echo
done
