import { readFileSync } from 'node:fs';
import yaml from 'js-yaml';
import Ajv, { type ValidateFunction } from 'ajv';
import addFormats from 'ajv-formats';

/**
 * Builds a validator for the MusicEvent schema defined in asyncapi.yaml.
 * The AsyncAPI document is the single source of truth — the schema is read
 * straight out of the spec, never hand-copied here.
 */
export class Validator {
  private readonly validateFn: ValidateFunction;

  constructor(specPath: string) {
    const doc = yaml.load(readFileSync(specPath, 'utf8')) as {
      components: { schemas: Record<string, unknown> };
    };

    const ajv = new Ajv({ strict: false, allErrors: true });
    addFormats(ajv);

    // Resolve MusicEvent via a JSON pointer so its internal $refs
    // (#/components/schemas/Location, .../Price) resolve against the same root.
    this.validateFn = ajv.compile({
      $ref: '#/components/schemas/MusicEvent',
      components: { schemas: doc.components.schemas },
    });
  }

  /** Returns an array of human-readable error strings (empty == valid). */
  errorsFor(payload: unknown): string[] {
    const valid = this.validateFn(payload);
    if (valid) return [];
    return (this.validateFn.errors ?? []).map((e) => {
      const where = e.instancePath || '(root)';
      return `${where}: ${e.message ?? 'failed validation'}`;
    });
  }

  isValid(payload: unknown): boolean {
    return this.errorsFor(payload).length === 0;
  }
}
