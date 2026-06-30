import type { Connection } from './connection.js';
import type { Validator } from './validate.js';
import { EXCHANGE, type MusicEvent } from './routing.js';

const SERVICE_NAME = 'ts-service';

/** Outcome of inspecting a single message body. */
export type Classification =
  | { status: 'valid'; payload: MusicEvent; errors: [] }
  | { status: 'invalid'; payload: MusicEvent; errors: string[] }
  | { status: 'unparseable'; payload: null; errors: string[] };

/**
 * Binds a queue to the topic exchange with a routing-key pattern and consumes
 * matching events, validating each one against the AsyncAPI contract.
 */
export class Subscriber {
  constructor(
    private readonly conn: Connection,
    private readonly validator: Validator,
    private readonly pattern: string,
  ) {}

  /**
   * Inspect a raw message body and classify it against the contract.
   * Pure (no broker / no I/O) so it can be unit-tested directly.
   */
  classify(body: string): Classification {
    let payload: MusicEvent;
    try {
      payload = JSON.parse(body) as MusicEvent;
    } catch (err) {
      return { status: 'unparseable', payload: null, errors: [(err as Error).message] };
    }
    const errors = this.validator.errorsFor(payload);
    return errors.length === 0
      ? { status: 'valid', payload, errors: [] }
      : { status: 'invalid', payload, errors };
  }

  async run(): Promise<void> {
    const channel = this.conn.channel;
    const { queue } = await channel.assertQueue(`${SERVICE_NAME}.events`, { durable: true });
    await channel.bindQueue(queue, EXCHANGE, this.pattern);

    console.log(`[${SERVICE_NAME}] ✓ subscribed — queue '${queue}' bound to '${this.pattern}'`);
    console.log(`[${SERVICE_NAME}]   waiting for music events… (Ctrl+C to exit)`);

    await channel.consume(queue, (msg) => {
      if (!msg) return;
      const routingKey = msg.fields.routingKey;
      const result = this.classify(msg.content.toString());

      if (result.status === 'valid') {
        const loc = result.payload.location ?? ({} as MusicEvent['location']);
        console.log(
          `[${SERVICE_NAME}] ← received ${routingKey} ✓ valid — ` +
            `${result.payload.title} · ${result.payload.artist} @ ${loc.venue}, ${loc.city}`,
        );
      } else if (result.status === 'invalid') {
        console.warn(`[${SERVICE_NAME}] ← received ${routingKey} ✗ INVALID — does not match contract:`);
        result.errors.forEach((e) => console.warn(`[${SERVICE_NAME}]     - ${e}`));
      } else {
        console.warn(`[${SERVICE_NAME}] ← received ${routingKey} ✗ unparseable JSON: ${result.errors[0]}`);
      }
      channel.ack(msg);
    });
  }
}
