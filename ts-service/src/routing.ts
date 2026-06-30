export const EXCHANGE = 'music.events';

export interface MusicEvent {
  id: string;
  title: string;
  artist: string;
  genre: string;
  location: { city: string; venue?: string; country: string };
  startsAt: string;
  endsAt?: string;
  price?: { amount: number; currency: string };
  submittedBy: string;
  submittedAt: string;
  [key: string]: unknown;
}

/**
 * Slugify a value the SAME way the Ruby service does (see ruby-service/lib/routing.rb):
 * lowercase, collapse any run of non-alphanumerics to a single '-', strip ends.
 * Keeps the routing key free of '.' so it never breaks AMQP topic word boundaries.
 */
export function slug(value: unknown): string {
  return String(value ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Build the topic routing key for an event: events.<city>.<genre> */
export function routingKeyFor(event: Partial<MusicEvent>): string {
  const city = slug(event.location?.city);
  const genre = slug(event.genre);
  return `events.${city}.${genre}`;
}
