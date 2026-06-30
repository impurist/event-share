import type { Connection } from './connection.js';
import type { Validator } from './validate.js';
import { EXCHANGE, routingKeyFor, type MusicEvent } from './routing.js';

const SERVICE_NAME = 'ts-service';

/**
 * Validates an event against the AsyncAPI contract, then publishes it to the
 * topic exchange using a routing key derived from its city + genre.
 */
export class Publisher {
  constructor(
    private readonly conn: Connection,
    private readonly validator: Validator,
  ) {}

  /** Returns the routing key used. Throws if invalid and force is false. */
  publish(event: MusicEvent, force = false): string {
    const errors = this.validator.errorsFor(event);
    if (errors.length > 0) {
      const detail = errors.map((e) => `  - ${e}`).join('\n');
      if (!force) {
        throw new Error(`event fails the AsyncAPI MusicEvent contract:\n${detail}`);
      }
      console.warn(`[${SERVICE_NAME}] ⚠ publishing INVALID event anyway (--force):\n${detail}`);
    }

    const routingKey = routingKeyFor(event);
    this.conn.channel.publish(EXCHANGE, routingKey, Buffer.from(JSON.stringify(event)), {
      contentType: 'application/json',
      persistent: true,
      type: 'music.event.published',
      appId: SERVICE_NAME,
    });
    console.log(`[${SERVICE_NAME}] → published ${routingKey}  (${event.title ?? '?'})`);
    return routingKey;
  }
}
