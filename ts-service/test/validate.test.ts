import { describe, it, expect } from 'vitest';
import { Validator } from '../src/validate.js';
import { SPEC_PATH, loadSample } from './helpers.js';

describe('Validator', () => {
  const validator = new Validator(SPEC_PATH);

  it('accepts a valid event', () => {
    expect(validator.errorsFor(loadSample('london-jazz'))).toEqual([]);
    expect(validator.isValid(loadSample('london-jazz'))).toBe(true);
  });

  it('accepts an event without the optional price/endsAt fields', () => {
    expect(validator.errorsFor(loadSample('berlin-techno'))).toEqual([]);
  });

  it('rejects an event that breaks the contract, reporting every violation', () => {
    const errors = validator.errorsFor(loadSample('invalid-london-jazz')).join('\n');
    expect(errors).toMatch(/title/); // missing required property
    expect(errors).toMatch(/country/); // country longer than 2 chars
    expect(errors).toMatch(/startsAt/); // not a date-time
  });

  it('rejects an unknown genre (enum)', () => {
    const event = { ...loadSample('london-jazz'), genre: 'polka' };
    expect(validator.isValid(event)).toBe(false);
  });

  it('rejects unknown top-level properties (additionalProperties: false)', () => {
    const event = { ...loadSample('london-jazz'), surprise: true };
    expect(validator.isValid(event)).toBe(false);
  });
});
