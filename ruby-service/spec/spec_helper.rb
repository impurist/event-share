# frozen_string_literal: true

require 'json'
require_relative '../boot' # Zeitwerk autoloads Routing, Validator, Publisher, Subscriber, ...

# Path to the AsyncAPI contract (repo root), the single source of truth that
# the validator loads. Overridable via SPEC_PATH.
SPEC_PATH = ENV.fetch('SPEC_PATH', File.expand_path('../../asyncapi.yaml', __dir__))

# Load a sample event JSON file from ../sample-events by name (without extension).
def load_sample(name)
  path = File.expand_path("../../sample-events/#{name}.json", __dir__)
  JSON.parse(File.read(path))
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end
