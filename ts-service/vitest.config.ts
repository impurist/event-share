import { defineConfig, configDefaults } from 'vitest/config';

export default defineConfig({
  test: {
    // Pact message-contract generation lives under test/pact and is run via the
    // dedicated `npm run test:pact` script, so keep it out of the fast unit run.
    exclude: [...configDefaults.exclude, 'test/pact/**'],
  },
});
