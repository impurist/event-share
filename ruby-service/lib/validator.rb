# frozen_string_literal: true

require 'yaml'
require 'json_schemer'

# Validates message payloads against the MusicEvent schema defined in
# asyncapi.yaml. The AsyncAPI document is the single source of truth — we never
# hand-copy the schema here, we read it straight out of the spec.
class Validator
  def initialize(spec_path)
    doc = YAML.safe_load_file(spec_path)
    schemas = doc.fetch('components').fetch('schemas')

    # Resolve MusicEvent via a JSON pointer so its internal $refs
    # (#/components/schemas/Location, .../Price) resolve against the same root.
    schema = {
      '$ref' => '#/components/schemas/MusicEvent',
      'components' => { 'schemas' => schemas }
    }

    @schemer = JSONSchemer.schema(schema)
  end

  # Returns an array of human-readable error strings (empty == valid).
  def errors_for(payload)
    @schemer.validate(payload).map do |err|
      pointer = err['data_pointer'].empty? ? '(root)' : err['data_pointer']
      "#{pointer}: #{err['type']} — #{err.fetch('error', 'failed validation')}"
    end
  end

  def valid?(payload)
    @schemer.valid?(payload)
  end
end
