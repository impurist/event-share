import { describe, it, expect } from 'vitest';
import { slug, routingKeyFor, type MusicEvent } from '../src/routing.js';
import { loadSample } from './helpers.js';

describe('slug', () => {
  it('lowercases', () => {
    expect(slug('London')).toBe('london');
  });

  it('collapses runs of non-alphanumerics into a single dash', () => {
    expect(slug('New York')).toBe('new-york');
    expect(slug('São  Paulo!!')).toBe('s-o-paulo');
  });

  it('strips leading and trailing dashes', () => {
    expect(slug('  -Berlin- ')).toBe('berlin');
  });

  it('never emits a dot (which would break AMQP topic word boundaries)', () => {
    expect(slug('a.b.c')).not.toContain('.');
  });

  it('handles null/undefined', () => {
    expect(slug(null)).toBe('');
    expect(slug(undefined)).toBe('');
  });
});

describe('routingKeyFor', () => {
  it('builds events.<city>.<genre> from a real sample event', () => {
    expect(routingKeyFor(loadSample<MusicEvent>('london-jazz'))).toBe('events.london.jazz');
  });

  it('slugifies multi-word cities', () => {
    const event = { genre: 'rock', location: { city: 'New York', country: 'US' } } as Partial<MusicEvent>;
    expect(routingKeyFor(event)).toBe('events.new-york.rock');
  });
});

it('routing matches the Ruby service for the same inputs', () => {
  // Mirrors ruby-service/spec/routing_spec.rb to keep the two implementations in lockstep.
  expect(slug('São  Paulo!!')).toBe('s-o-paulo');
  expect(routingKeyFor(loadSample<MusicEvent>('berlin-techno'))).toBe('events.berlin.techno');
});
