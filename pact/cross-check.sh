#!/usr/bin/env bash
# Local cross-contract validation (no broker, no credentials): validate each
# generated consumer pact's message against asyncapi.yaml. A local proxy for
# what PactFlow does server-side during can-i-deploy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Reuses ts-service's Validator + deps.
exec npm --prefix "$ROOT/ts-service" run --silent cross-check
