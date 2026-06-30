import { readFileSync } from 'node:fs';
import { basename } from 'node:path';
import { connect } from './connection.js';
import { Validator } from './validate.js';
import { Publisher } from './publisher.js';
import { SPEC_PATH } from './spec-path.js';
import type { MusicEvent } from './routing.js';

// Publish one or more music events from JSON files.
//
//   npm run publish -- [--force] <event.json> [<event.json> ...]
//
//   --force   publish even if the event fails the AsyncAPI contract
//             (useful for demonstrating consumer-side validation)
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const files = args.filter((a) => a !== '--force');

  if (files.length === 0) {
    console.error('usage: npm run publish -- [--force] <event.json> [<event.json> ...]');
    process.exit(64);
  }

  const validator = new Validator(SPEC_PATH);
  const conn = await connect();
  const publisher = new Publisher(conn, validator);

  let exitCode = 0;
  for (const file of files) {
    try {
      const event = JSON.parse(readFileSync(file, 'utf8')) as MusicEvent;
      publisher.publish(event, force);
    } catch (err) {
      console.error(`[ts-service] ✗ refused ${basename(file)}: ${(err as Error).message}`);
      exitCode = 1;
    }
  }

  await conn.close();
  process.exit(exitCode);
}

main().catch((err) => {
  console.error('[ts-service] fatal:', err);
  process.exit(1);
});
