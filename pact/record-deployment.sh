#!/usr/bin/env bash
# Record a deployment of each pacticipant to an environment (run after a
# successful can-i-deploy + actual deploy).
#
# Env-driven — see pact/.env.example. Run with DRY_RUN=1 to print the commands.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

for participant in "${PACTICIPANTS[@]}"; do
  echo "== record-deployment: $participant @ $GIT_SHA → $DEPLOY_ENVIRONMENT =="
  pactbroker_cli record-deployment \
    --pacticipant "$participant" \
    --version "$GIT_SHA" \
    --environment "$DEPLOY_ENVIRONMENT"
  echo
done
