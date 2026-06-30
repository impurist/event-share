import { connect } from './connection.js';
import { Validator } from './validate.js';
import { Subscriber } from './subscriber.js';
import { SPEC_PATH } from './spec-path.js';

const PATTERN = process.env.SUBSCRIBE_PATTERN ?? 'events.#';

async function main(): Promise<void> {
  const validator = new Validator(SPEC_PATH);
  const conn = await connect();
  const subscriber = new Subscriber(conn, validator, PATTERN);

  const shutdown = async () => {
    await conn.close().catch(() => {});
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  await subscriber.run();
}

main().catch((err) => {
  console.error('[ts-service] fatal:', err);
  process.exit(1);
});
