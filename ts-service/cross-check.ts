// LOCAL proxy for PactFlow's cross-contract validation.
//
// For every generated consumer message pact (from BOTH services), validate its
// example message against the AsyncAPI MusicEvent schema — the provider contract.
// This mirrors what PactFlow's AsyncAPI BDCT does server-side: a consumer must
// consume a valid SUBSET of the provider's contract. Exits non-zero on violation.
//
// Reuses the real Validator (src/validate.ts) so it can't drift from the runtime.
// Invoked via pact/cross-check.sh → `npm run cross-check`.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { Validator } from './src/validate.js';

const SPEC_PATH = process.env.SPEC_PATH ?? fileURLToPath(new URL('../asyncapi.yaml', import.meta.url));
const validator = new Validator(SPEC_PATH);

const pactDirs = [
  fileURLToPath(new URL('./pacts', import.meta.url)),
  fileURLToPath(new URL('../ruby-service/pacts', import.meta.url)),
];
const files = pactDirs.flatMap((dir) =>
  existsSync(dir)
    ? readdirSync(dir)
        .filter((f) => f.endsWith('.json'))
        .map((f) => path.join(dir, f))
    : [],
);

if (files.length === 0) {
  console.error('No consumer pacts found. Generate them first (npm run test:pact / generate_consumer_pact.rb).');
  process.exit(1);
}

// Extract { description, contents } for each async message, supporting both
// Pact v4 (interactions[].contents.content) and v3 (messages[].contents).
function asyncMessages(pact: any): Array<{ description: string; contents: unknown }> {
  if (Array.isArray(pact.interactions)) {
    return pact.interactions
      .filter((i: any) => i.type === 'Asynchronous/Messages')
      .map((i: any) => ({ description: i.description, contents: i.contents?.content ?? i.contents }));
  }
  return (pact.messages ?? []).map((m: any) => ({ description: m.description, contents: m.contents }));
}

let failures = 0;
for (const file of files) {
  const pact = JSON.parse(readFileSync(file, 'utf8'));
  const consumer = pact.consumer?.name ?? '?';
  const provider = pact.provider?.name ?? '?';
  for (const msg of asyncMessages(pact)) {
    const errors = validator.errorsFor(msg.contents);
    if (errors.length === 0) {
      console.log(`✓ ${consumer} → ${provider}: "${msg.description}" is a valid subset of the AsyncAPI contract`);
    } else {
      failures++;
      console.error(`✗ ${consumer} → ${provider}: "${msg.description}" does NOT satisfy the provider contract:`);
      errors.forEach((e) => console.error(`    - ${e}`));
    }
  }
}

console.log('');
if (failures === 0) {
  console.log('CROSS-CHECK PASSED — every consumer message satisfies asyncapi.yaml');
  process.exit(0);
} else {
  console.error(`CROSS-CHECK FAILED — ${failures} message(s) violate the provider contract`);
  process.exit(1);
}
