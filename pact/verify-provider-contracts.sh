#!/usr/bin/env bash
# Provider self-verification for BOTH services (local, no broker).
# Proves each publisher emits messages that conform to asyncapi.yaml.
# Exits non-zero if either provider fails — this is the gate whose result is
# attached to the provider contract at publish time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== ts-service: provider self-verification =="
( cd "$ROOT/ts-service" && npm run --silent verify:provider )

echo
echo "== ruby-service: provider self-verification =="
# Needs Ruby 4.0.x (see mise.toml). If you don't have it locally, run via Docker:
#   docker compose run --rm --no-deps -v "$ROOT:/work" -w /work/ruby-service ruby-service \
#     ruby bin/verify_provider_contract.rb
( cd "$ROOT/ruby-service" && ruby bin/verify_provider_contract.rb )

echo
echo "Both providers self-verified ✓"
