import amqplib, { type Channel, type ChannelModel } from 'amqplib';
import { EXCHANGE } from './routing.js';

export interface Connection {
  channel: Channel;
  close: () => Promise<void>;
}

const sleep = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Connect to RabbitMQ and assert the shared durable topic exchange.
 * Retries the initial connection so the service can start before the broker is
 * accepting connections (e.g. under docker-compose, where a healthcheck can pass
 * moments before the AMQP listener is ready).
 */
export async function connect(
  url = process.env.RABBITMQ_URL ?? 'amqp://guest:guest@localhost:5672',
  { maxAttempts = 30, retryDelayMs = 2000 }: { maxAttempts?: number; retryDelayMs?: number } = {},
): Promise<Connection> {
  let lastErr: unknown;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const conn: ChannelModel = await amqplib.connect(url);
      const channel = await conn.createChannel();
      await channel.assertExchange(EXCHANGE, 'topic', { durable: true, autoDelete: false });
      return {
        channel,
        close: async () => {
          await channel.close();
          await conn.close();
        },
      };
    } catch (err) {
      lastErr = err;
      if (attempt >= maxAttempts) break;
      console.warn(
        `[ts-service] broker not ready (attempt ${attempt}/${maxAttempts}): ` +
          `${(err as Error).message} — retrying in ${retryDelayMs}ms`,
      );
      await sleep(retryDelayMs);
    }
  }
  throw lastErr;
}
