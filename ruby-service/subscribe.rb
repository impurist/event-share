#!/usr/bin/env ruby
# frozen_string_literal: true

# Long-running subscriber. Binds to the topic exchange with SUBSCRIBE_PATTERN
# and validates every event it receives against the AsyncAPI contract.

require_relative 'boot'

SPEC_PATH = ENV.fetch('SPEC_PATH', File.expand_path('../asyncapi.yaml', __dir__))
PATTERN = ENV.fetch('SUBSCRIBE_PATTERN', 'events.#')

$stdout.sync = true

validator = Validator.new(SPEC_PATH)
connection = Connection.new
subscriber = Subscriber.new(connection, validator, pattern: PATTERN)

trap('INT')  { connection.close; exit }
trap('TERM') { connection.close; exit }

subscriber.run
