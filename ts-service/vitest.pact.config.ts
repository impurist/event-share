import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Only the Pact message-contract generation tests.
    include: ['test/pact/**/*.test.ts'],
  },
});
