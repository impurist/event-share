# Music Performance Event Sharing — an AsyncAPI example

A small, runnable **event-driven** example described by a single
[AsyncAPI 3.0](./asyncapi.yaml) document.

Users submit live-music performance events. Each event is **published** to a
RabbitMQ **topic exchange** with a routing key built from its **location** and
**genre**. Subscribers express interest by binding a routing-key **pattern** —
so you subscribe to *"jazz anywhere"* or *"everything in London"* without the
publisher knowing or caring who is listening.

Two services — one **Ruby**, one **TypeScript** — each both **publish** and
**subscribe**, proving cross-language interop against one shared contract.

```
                            topic exchange: music.events
                          ┌──────────────────────────────────┐
   ruby-service ─publish─▶ │  routing key: events.<city>.<genre> │ ─▶ binding events.london.#  ─▶ ruby-service
   ts-service   ─publish─▶ │  e.g. events.london.jazz           │ ─▶ binding events.*.jazz    ─▶ ts-service
                          └──────────────────────────────────┘
                                         ▲
                          asyncapi.yaml  │  (both services validate every
                          is the single ─┘   published & received message
                          source of truth     against the MusicEvent schema)
```

## The contract is the source of truth

[`asyncapi.yaml`](./asyncapi.yaml) defines the `music.events` topic exchange, the
`events.{city}.{genre}` channel address, the `send`/`receive` operations, and the
`MusicEvent` payload schema (AsyncAPI 3.0.0 + AMQP binding 0.3.0).

Neither service hand-copies the schema. At runtime each one **loads
`asyncapi.yaml` and validates against it** — Ruby via
[`json_schemer`](ruby-service/lib/validator.rb), TypeScript via
[`ajv`](ts-service/src/validate.ts). Change the spec and both sides change
together.

## Routing — location + genre is the topic

The routing key is `events.<city>.<genre>` (city and genre are slugified:
lowercased, non-alphanumerics → `-`). AMQP topic wildcards: `*` = exactly one
word, `#` = zero or more words.

With the default subscriptions — **ts-service → `events.*.jazz`** (jazz anywhere)
and **ruby-service → `events.london.#`** (everything in London):

| Published event | routing key            | ts (`events.*.jazz`) | ruby (`events.london.#`) |
| --------------- | ---------------------- | :------------------: | :----------------------: |
| London jazz     | `events.london.jazz`   |          ✅          |            ✅            |
| Berlin jazz     | `events.berlin.jazz`   |          ✅          |            ❌            |
| London rock     | `events.london.rock`   |          ❌          |            ✅            |
| Berlin techno   | `events.berlin.techno` |          ❌          |            ❌            |

Subscriptions are configurable via the `SUBSCRIBE_PATTERN` env var (see
[`docker-compose.yml`](./docker-compose.yml)).

## Run it

Requires Docker.

```bash
docker compose up --build
```

This starts RabbitMQ plus both services. You'll see each subscriber connect:

```
music-ruby-service  | [ruby-service] ✓ subscribed — queue 'ruby-service.events' bound to 'events.london.#'
music-ts-service    | [ts-service] ✓ subscribed — queue 'ts-service.events' bound to 'events.*.jazz'
```

RabbitMQ's management UI is at <http://localhost:15672> (guest / guest) — you can
watch the `music.events` exchange, the two queues, and their bindings live.

### Publish events and watch routing

In another terminal, publish from either service (the publisher CLI takes one or
more event JSON files):

```bash
# London jazz → delivered to BOTH subscribers
docker compose exec ruby-service ruby publish.rb sample-events/london-jazz.json

# Berlin jazz → ts only (jazz anywhere), not ruby (London only)
docker compose exec ts-service npm run publish -- sample-events/berlin-jazz.json

# London rock → ruby only (London anything), not ts (jazz only)
docker compose exec ruby-service ruby publish.rb sample-events/london-rock.json

# Berlin techno → neither default subscription matches
docker compose exec ts-service npm run publish -- sample-events/berlin-techno.json
```

A received, contract-valid event logs like:

```
music-ts-service    | [ts-service] ← received events.london.jazz ✓ valid — Midnight Quartet — Live · The Blue Notes @ Ronnie Scott's, London
```

Publishing from Ruby and receiving in TypeScript (and vice-versa) demonstrates
the cross-language interop.

## Negative test — the contract actually governs both sides

[`sample-events/invalid-london-jazz.json`](./sample-events/invalid-london-jazz.json)
breaks the schema (missing required `title`, a `country` that isn't a 2-letter
code, a non-date `startsAt`).

```bash
# Publisher refuses it up front:
docker compose exec ruby-service ruby publish.rb sample-events/invalid-london-jazz.json
#   [ruby-service] ✗ refused invalid-london-jazz.json: event fails the AsyncAPI MusicEvent contract: ...

# Force it onto the bus to prove consumer-side validation also catches it:
docker compose exec ruby-service ruby publish.rb --force sample-events/invalid-london-jazz.json
#   subscribers log: ← received events.london.jazz ✗ INVALID — does not match contract: ...
```

(The TypeScript publisher takes the same flag: `npm run publish -- --force <file>`.)

## Tests

Both services have unit tests that run **without a broker** — they cover the
shared routing/slug rules, validation against the AsyncAPI contract, the
publisher's validate-before-send behaviour (with a mocked channel), and the
subscriber's message classification.

```bash
# Ruby (RSpec)
cd ruby-service && bundle install && bundle exec rspec

# TypeScript (Vitest)
cd ts-service && npm install && npm test
```

The routing tests are deliberately mirrored across both languages (e.g. the
`São Paulo!!` → `s-o-paulo` case) so the Ruby and TypeScript slug rules can't
drift apart.

## Validate / explore the spec

```bash
# Validate the AsyncAPI document
npx -y @asyncapi/cli validate asyncapi.yaml

# Generate browsable HTML docs into ./docs
npx -y @asyncapi/cli generate html asyncapi.yaml -o ./docs
```

## Project layout

```
asyncapi.yaml          AsyncAPI 3.0 contract — the source of truth (also the BDCT provider contract)
mise.toml              Pinned Ruby / Node versions — the toolchain source of truth
docker-compose.yml     RabbitMQ + both services
sample-events/         Example event payloads (incl. one invalid)
pact/                  PactFlow BDCT tooling — publish / can-i-deploy / cross-check scripts (env-driven)
ruby-service/          Ruby publisher + subscriber (bunny, json_schemer, zeitwerk) + RSpec
                       bin/verify_provider_contract.rb · bin/generate_consumer_pact.rb
ts-service/            TypeScript publisher + subscriber (amqplib, ajv) + Vitest
                       src/verify-provider-contract.ts · test/pact/ · cross-check.ts
```

## Toolchain versions

[`mise.toml`](./mise.toml) pins the Ruby and Node versions for the whole project
and is the single source of truth — the Dockerfiles (`ruby:4.0.5`,
`node:26.4.0-slim`) match it exactly. With [mise](https://mise.jdx.dev) installed:

```bash
mise install        # installs Ruby + Node at the pinned versions
```

You don't need mise to run the Docker path — the images already carry the right
versions.

## Running a service without Docker

Use this if `docker compose up --build` fails to install gems/npm packages —
e.g. behind a **corporate TLS-intercepting proxy** (Zscaler and similar), where
the in-container package installs can't verify the proxy's root CA. The broker
still runs fine in Docker; only the two service images need building, so just run
them on your host (which already trusts the corp CA) against a Dockerised broker:

```bash
docker compose up -d rabbitmq      # broker only — no image build needed
```

Each service can run against any reachable broker via `RABBITMQ_URL`
(default `amqp://guest:guest@localhost:5672`). Run `mise install` first so you're
on the pinned Ruby/Node. For example:

```bash
# Ruby
cd ruby-service && bundle install
SUBSCRIBE_PATTERN='events.#' ruby subscribe.rb        # consumer
ruby publish.rb ../sample-events/london-jazz.json     # publisher

# TypeScript
cd ts-service && npm install
SUBSCRIBE_PATTERN='events.#' npm run subscribe         # consumer
npm run publish -- ../sample-events/london-jazz.json   # publisher
```

## PactFlow Bi-Directional Contract Testing (AsyncAPI)

This example drives **PactFlow BDCT** using `asyncapi.yaml` as the **provider
contract**. The artifacts and scripts live under [`pact/`](./pact); everything
runs locally, and publishing to a tenant is env-driven (you supply the creds).

> The provider contract is published with `--specification asyncapi` plus its
> self-verification results; the consumer message pacts are **Pact v4**
> (`Asynchronous/Messages`).

### The model — full symmetric

Both services are **both** a provider and a consumer. Two PactFlow pacticipants
(contract identities, distinct from the service directories):

| Pacticipant (service dir) | As **provider** (AsyncAPI contract + self-verification) | As **consumer** (message pact → provider) |
| --- | --- | --- |
| `event-share-broker-service` (`ruby-service`) | `asyncapi.yaml`, verified by its publisher | message pact → **`event-share-user-service`** |
| `event-share-user-service` (`ts-service`)   | `asyncapi.yaml`, verified by its publisher | message pact → **`event-share-broker-service`** |

- **Provider self-verification** proves each publisher emits messages that conform
  to `asyncapi.yaml` (reuses `Validator` + `Publisher` + the sample events). Its
  exit code is attached to the published provider contract — the messaging analogue
  of the OAS verification step in BDCT.
- **Consumer message pacts** declare the fields each subscriber relies on (type
  matchers) and run the example through the real handler (`Subscriber.classify`).
  TS uses `@pact-foundation/pact`; Ruby emits a spec-compliant Pact v3 message pact
  directly (the official `pact-message-ruby` consumer DSL is unmaintained).
- **Cross-contract validation** (consumer message ⊆ AsyncAPI provider contract) is
  what PactFlow does server-side on `can-i-deploy`. [`pact/cross-check.sh`](./pact/cross-check.sh)
  reproduces it **locally** so the whole loop is demonstrable before any tenant call.

### Run it locally (no broker, no credentials)

```bash
# 1. Provider self-verification — each publisher conforms to asyncapi.yaml
./pact/verify-provider-contracts.sh

# 2. Generate the consumer message pacts → each service's pacts/
(cd ts-service && npm run test:pact)
(cd ruby-service && ruby bin/generate_consumer_pact.rb)   # needs Ruby 4.0.x (mise) or run via Docker

# 3. Cross-check: do the consumer pacts satisfy the AsyncAPI provider contract?
./pact/cross-check.sh
```

> Ruby tooling needs the pinned Ruby 4.0.x (`mise install`). Without it, run any
> Ruby step in the container, e.g.:
> ```bash
> docker compose run --rm --no-deps -v "$PWD:/work" -w /work/ruby-service ruby-service \
>   ruby bin/generate_consumer_pact.rb
> ```

### Publish to PactFlow + can-i-deploy (env-driven)

```bash
cp pact/.env.example pact/.env     # then fill in PACT_BROKER_BASE_URL + PACT_BROKER_TOKEN
./pact/publish-provider-contracts.sh   # publishes asyncapi.yaml (x2) with self-verification results
./pact/publish-consumer-pacts.sh       # publishes both consumer message pacts
./pact/can-i-deploy.sh                 # PactFlow cross-validates + answers safe-to-deploy
./pact/record-deployment.sh            # after a successful deploy
```

Every script honours `DRY_RUN=1` to print the exact commands without executing
them, and uses the consolidated [`pact` CLI](https://github.com/pact-foundation/pact-cli)
via its `pactfoundation/pact` Docker image so no CLI install is needed.

**→ Full step-by-step workflow with commands: [`pact/README.md`](./pact/README.md)**

---

> This BDCT layer sits on top of the runtime example below it — the same
> `asyncapi.yaml` is the contract for the live RabbitMQ services *and* the
> provider contract published to PactFlow.
