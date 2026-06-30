#!/usr/bin/env bash
# Publish BOTH consumer message pacts to PactFlow.
#   ts-service/pacts/ts-service-ruby-service.json   (ts-service  → ruby-service)
#   ruby-service/pacts/ruby-service-ts-service.json (ruby-service → ts-service)
#
# Generate them first:
#   (cd ts-service && npm run test:pact)
#   (cd ruby-service && ruby bin/generate_consumer_pact.rb)   # or via Docker
#
# Env-driven — see pact/.env.example. Run with DRY_RUN=1 to print the command.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# pact-broker publish auto-detects the consumer/provider names from each file.
pactbroker_cli publish \
  ts-service/pacts \
  ruby-service/pacts \
  --consumer-app-version "$GIT_SHA" \
  --branch "$GIT_BRANCH"

echo "Consumer pacts published."
