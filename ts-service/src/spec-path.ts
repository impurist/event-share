import { fileURLToPath } from 'node:url';

/** Path to asyncapi.yaml — overridable via SPEC_PATH (set in docker-compose). */
export const SPEC_PATH =
  process.env.SPEC_PATH ?? fileURLToPath(new URL('../../asyncapi.yaml', import.meta.url));
