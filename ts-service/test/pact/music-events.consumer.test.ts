import { fileURLToPath } from 'node:url';
import { describe, it } from 'vitest';
import { PactV4, MatchersV3 } from '@pact-foundation/pact';
import { Subscriber } from '../../src/subscriber.js';
import { Validator } from '../../src/validate.js';
import type { Connection } from '../../src/connection.js';
import { SPEC_PATH } from '../helpers.js';

const { like } = MatchersV3;

const PACT_DIR = fileURLToPath(new URL('../../pacts', import.meta.url));

// The consumer's real message handler IS Subscriber.classify (pure, broker-free).
// The pact passes only if the consumer can successfully process the message.
const subscriber = new Subscriber({} as Connection, new Validator(SPEC_PATH), 'events.#');

describe('ts-service consumes MusicEventPublished from ruby-service', () => {
  // PactV4 → Pact Specification v4 (Asynchronous/Messages interactions).
  const pact = new PactV4({
    consumer: 'ts-service',
    provider: 'ruby-service',
    dir: PACT_DIR,
  });

  it('can handle a MusicEventPublished event', () => {
    return pact
      .addAsynchronousInteraction()
      .expectsToReceive('a MusicEventPublished event', (builder) => {
        builder
          // Only the fields this subscriber relies on, as type matchers. Example
          // values are themselves contract-valid so the handler (classify) accepts them.
          .withJSONContent({
            id: like('3f1a8c2e-9b7d-4e6a-bc11-2f0d4a9e7c01'),
            title: like('Midnight Quartet — Live'),
            artist: like('The Blue Notes'),
            genre: like('jazz'),
            location: like({
              city: like('london'),
              venue: like("Ronnie Scott's"),
              country: like('GB'),
            }),
            startsAt: like('2026-07-12T20:00:00Z'),
            submittedBy: like('user_42'),
            submittedAt: like('2026-06-30T09:00:00Z'),
          })
          // PILOT HOOK: how PactFlow links a message pact to an AsyncAPI channel/operation
          // is pilot-specific. These keys identify the exchange + a representative routing
          // key; adjust to whatever the AsyncAPI-BDCT pilot expects.
          .withMetadata({
            contentType: 'application/json',
            channel: 'music.events',
            routingKey: 'events.london.jazz',
          });
      })
      .executeTest(async (message) => {
        const result = subscriber.classify(JSON.stringify(message.contents.content));
        if (result.status !== 'valid') {
          throw new Error(`consumer cannot process message: ${result.errors.join('; ')}`);
        }
      });
  });
});
