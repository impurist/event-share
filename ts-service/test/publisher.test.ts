import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Publisher } from '../src/publisher.js';
import { Validator } from '../src/validate.js';
import { EXCHANGE, type MusicEvent } from '../src/routing.js';
import type { Connection } from '../src/connection.js';
import { SPEC_PATH, loadSample } from './helpers.js';

describe('Publisher', () => {
  const validator = new Validator(SPEC_PATH);
  let publish: ReturnType<typeof vi.fn>;
  let conn: Connection;
  let publisher: Publisher;

  beforeEach(() => {
    publish = vi.fn();
    conn = { channel: { publish }, close: vi.fn() } as unknown as Connection;
    publisher = new Publisher(conn, validator);
  });

  it('publishes a valid event with the derived routing key and returns it', () => {
    const key = publisher.publish(loadSample<MusicEvent>('london-jazz'));

    expect(key).toBe('events.london.jazz');
    expect(publish).toHaveBeenCalledTimes(1);
    const [exchange, routingKey, content, opts] = publish.mock.calls[0];
    expect(exchange).toBe(EXCHANGE);
    expect(routingKey).toBe('events.london.jazz');
    expect(opts).toMatchObject({ contentType: 'application/json', persistent: true });
    expect(JSON.parse((content as Buffer).toString())).toMatchObject({ genre: 'jazz' });
  });

  it('throws on an invalid event and does not publish', () => {
    expect(() => publisher.publish(loadSample<MusicEvent>('invalid-london-jazz'))).toThrow(
      /MusicEvent contract/,
    );
    expect(publish).not.toHaveBeenCalled();
  });

  it('publishes an invalid event when forced', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(() => publisher.publish(loadSample<MusicEvent>('invalid-london-jazz'), true)).not.toThrow();
    expect(publish).toHaveBeenCalledTimes(1);
    warn.mockRestore();
  });
});
