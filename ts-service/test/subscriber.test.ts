import { describe, it, expect } from 'vitest';
import { Subscriber } from '../src/subscriber.js';
import { Validator } from '../src/validate.js';
import type { Connection } from '../src/connection.js';
import { SPEC_PATH, loadSample } from './helpers.js';

describe('Subscriber.classify', () => {
  const validator = new Validator(SPEC_PATH);
  // classify does not touch the broker, so a dummy connection is fine.
  const subscriber = new Subscriber({} as Connection, validator, 'events.#');

  it('classifies a valid message body as valid with the parsed payload', () => {
    const result = subscriber.classify(JSON.stringify(loadSample('london-jazz')));
    expect(result.status).toBe('valid');
    expect(result.payload?.title).toBe('Midnight Quartet — Live');
    expect(result.errors).toEqual([]);
  });

  it('classifies a contract-violating body as invalid with errors', () => {
    const result = subscriber.classify(JSON.stringify(loadSample('invalid-london-jazz')));
    expect(result.status).toBe('invalid');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('classifies non-JSON as unparseable', () => {
    const result = subscriber.classify('{not json');
    expect(result.status).toBe('unparseable');
    expect(result.payload).toBeNull();
    expect(typeof result.errors[0]).toBe('string');
  });
});
