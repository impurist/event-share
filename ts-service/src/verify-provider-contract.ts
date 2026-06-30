// Provider self-verification for Bi-Directional Contract Testing.
//
// Proves this service's PUBLISHER emits messages that conform to the AsyncAPI
// provider contract (../asyncapi.yaml). This is the messaging analogue of the
// OAS "provider verification" step in BDCT: the provider contract uploaded to
// PactFlow is the spec PLUS the result of this check.
//
// The exit code (0 = pass) is what feeds
//   pactflow publish-provider-contract --verification-exit-code <code>

import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Validator } from './validate.js';
import { Publisher } from './publisher.js';
import type { Connection } from './connection.js';
import type { MusicEvent } from './routing.js';

const SPEC_PATH = process.env.SPEC_PATH ?? fileURLToPath(new URL('../../asyncapi.yaml', import.meta.url));
const SAMPLES_DIR = process.env.SAMPLES_DIR ?? fileURLToPath(new URL('../../sample-events', import.meta.url));

// Stand-in for the broker channel: records what the publisher would send.
const captured: Buffer[] = [];
const fakeConn = {
  channel: {
    publish: (_exchange: string, _routingKey: string, content: Buffer): boolean => {
      captured.push(content);
      return true;
    },
  },
  close: async (): Promise<void> => {},
} as unknown as Connection;

const validator = new Validator(SPEC_PATH);
const publisher = new Publisher(fakeConn, validator);

// The representative messages this provider publishes are the valid sample events.
const samples = readdirSync(SAMPLES_DIR)
  .filter((f) => f.endsWith('.json') && !f.startsWith('invalid'))
  .sort();

let failures = 0;
for (const name of samples) {
  const event = JSON.parse(readFileSync(`${SAMPLES_DIR}/${name}`, 'utf8')) as MusicEvent;
  try {
    publisher.publish(event); // validates against the contract, then "publishes"
    const published = JSON.parse(captured[captured.length - 1].toString());
    const errors = validator.errorsFor(published);
    if (errors.length === 0) {
      console.log(`✓ ${name} → publishes a contract-valid MusicEventPublished`);
    } else {
      failures++;
      console.error(`✗ ${name} → published message violates the contract:`);
      errors.forEach((e) => console.error(`    - ${e}`));
    }
  } catch (err) {
    failures++;
    console.error(`✗ ${name} → publisher refused (does not conform): ${(err as Error).message}`);
  }
}

console.log('');
if (failures === 0) {
  console.log(`PROVIDER SELF-VERIFICATION PASSED — ${samples.length} message(s) conform to asyncapi.yaml`);
  process.exit(0);
} else {
  console.error(
    `PROVIDER SELF-VERIFICATION FAILED — ${failures} of ${samples.length} message(s) violate the contract`,
  );
  process.exit(1);
}
