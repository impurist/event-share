# PactFlow Bi-Directional Contract Testing — workflow

Operational guide for the BDCT tooling in this directory. For the conceptual
overview see the [main README](../README.md#pactflow-bi-directional-contract-testing-asyncapi).

> contract is `asyncapi.yaml`, published with `--specification asyncapi`.

## Pacticipants

Two contract identities (distinct from the service directories):

| Pacticipant | Service dir | Role |
| --- | --- | --- |
| `event-share-broker-service` | `ruby-service/` | provider **and** consumer |
| `event-share-user-service`   | `ts-service/`   | provider **and** consumer |

Each service **provides** the AsyncAPI contract (its publisher self-verifies
against it) and **consumes** messages from the other (a Pact v4 message pact).

```
                 provider contract = asyncapi.yaml (+ self-verification results)
                 ┌──────────────────────────────┐
 broker-service ─┤ publishes provider contract   ├─┐
 user-service  ──┤ publishes provider contract   ├─┤
                 └──────────────────────────────┘ │  PactFlow cross-validates
                 ┌──────────────────────────────┐ │  each consumer pact ⊆ the
 user-service  ─▶│ consumer pact → broker-service├─┘  target's AsyncAPI contract
 broker-service ▶│ consumer pact → user-service  │      → can-i-deploy
                 └──────────────────────────────┘
```

## Prerequisites

- **Docker** (the pact CLI runs via the `pactfoundation/pact` image — no local install).
- **Node** + **Ruby** at the pinned versions (`mise install`) to generate pacts / run self-verification. Ruby steps can run in the container instead (see below).
- A **PactFlow** broker + a read/write **token**.

## Configure credentials

```bash
cp pact/.env.example pact/.env      # then edit PACT_BROKER_BASE_URL + PACT_BROKER_TOKEN
```

`_common.sh` loads `pact/.env` then `pact/.env.local` as **defaults** — anything
already exported in your shell / CI wins. Environment variables:

| Variable | Purpose | Default |
| --- | --- | --- |
| `PACT_BROKER_BASE_URL` | broker URL (required) | — |
| `PACT_BROKER_TOKEN` | bearer token (required) | — |
| `GIT_SHA` | version stamped on contracts | current git short SHA |
| `GIT_BRANCH` | branch stamped on contracts | current git branch |
| `DEPLOY_ENVIRONMENT` | env for can-i-deploy / record-deployment | `production` |
| `PACT_IMAGE` | pact CLI image | `pactfoundation/pact:latest` |
| `DRY_RUN` | print commands instead of running them | unset |

> **Local broker:** if PactFlow runs on your host, use `localhost` in the URL
> (e.g. `http://localhost:9292`). The scripts rewrite `localhost`/`127.0.0.1` to
> `host.docker.internal` so the CLI container can reach it.

Add `DRY_RUN=1` to any command below to print the exact CLI invocation without
executing it.

## 1. Verify + generate locally (no broker needed)

```bash
# Provider self-verification — each publisher conforms to asyncapi.yaml
./pact/verify-provider-contracts.sh

# Consumer message pacts (Pact v4) → each service's pacts/
(cd ts-service && npm run test:pact)
(cd ruby-service && ruby bin/generate_consumer_pact.rb)

# Local cross-validation: do the consumer pacts satisfy the AsyncAPI contract?
./pact/cross-check.sh
```

`cross-check.sh` is a local proxy for PactFlow's server-side cross-contract
validation — handy to run before publishing.

> **No local Ruby 4.0.x?** Run any Ruby step in the container:
> ```bash
> docker compose run --rm --no-deps -v "$PWD:/work" -w /work/ruby-service \
>   ruby-service ruby bin/generate_consumer_pact.rb
> ```

## 2. Publish to PactFlow

```bash
# Provider contracts (asyncapi.yaml + self-verification results) for both pacticipants.
# This re-runs each self-verification and attaches its output to the contract.
./pact/publish-provider-contracts.sh

# Consumer message pacts for both pacticipants.
./pact/publish-consumer-pacts.sh
```

## 3. Gate deployment

```bash
# PactFlow cross-validates consumer pacts against provider contracts and
# answers whether each pacticipant is safe to deploy.
./pact/can-i-deploy.sh

# After a successful deploy, record it:
./pact/record-deployment.sh
```

## Scripts

| Script | Runs | Broker? |
| --- | --- | --- |
| `verify-provider-contracts.sh` | provider self-verification (both) | no |
| `cross-check.sh` | local consumer-vs-contract validation | no |
| `publish-provider-contracts.sh` | `pact pactflow publish-provider-contract` ×2 | yes |
| `publish-consumer-pacts.sh` | `pact broker publish` | yes |
| `can-i-deploy.sh` | `pact broker can-i-deploy` per pacticipant | yes |
| `record-deployment.sh` | `pact broker record-deployment` per pacticipant | yes |
| `_common.sh` | shared env + CLI wrappers (sourced) | — |

## Troubleshooting

- **`ECONNREFUSED … localhost:9292`** — the CLI runs in a container; use `localhost`
  in `PACT_BROKER_BASE_URL` (auto-mapped to `host.docker.internal`), and ensure the
  broker is reachable from Docker.
- **400 `#/contract/selfVerificationResults/content is missing`** — the provider
  contract publish must include self-verification results. `publish-provider-contracts.sh`
  already attaches them via `--verification-results` + `--verification-results-content-type`.
- **Wrong token used** — an exported env var wins over `pact/.env`. Check with
  `DRY_RUN=1 ./pact/publish-consumer-pacts.sh` and unset any stale shell exports.
