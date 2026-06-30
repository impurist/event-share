import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/** Absolute path to the AsyncAPI contract at the repo root. */
export const SPEC_PATH =
  process.env.SPEC_PATH ?? fileURLToPath(new URL('../../asyncapi.yaml', import.meta.url));

/** Load a sample event JSON file from ../../sample-events by name (no extension). */
export function loadSample<T = Record<string, unknown>>(name: string): T {
  const path = fileURLToPath(new URL(`../../sample-events/${name}.json`, import.meta.url));
  return JSON.parse(readFileSync(path, 'utf8')) as T;
}
