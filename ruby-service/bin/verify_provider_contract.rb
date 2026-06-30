#!/usr/bin/env ruby
# frozen_string_literal: true

# Provider self-verification for Bi-Directional Contract Testing.
#
# Proves this service's PUBLISHER emits messages that conform to the AsyncAPI
# provider contract (../asyncapi.yaml). This is the messaging analogue of the
# OAS "provider verification" step in BDCT: the provider contract uploaded to
# PactFlow is the spec PLUS the result of this check.
#
# The exit code (0 = pass) is what feeds
#   pactflow publish-provider-contract --verification-exit-code <code>

require 'json'
require_relative '../boot'

SPEC_PATH = ENV.fetch('SPEC_PATH', File.expand_path('../../asyncapi.yaml', __dir__))
SAMPLES_DIR = ENV.fetch('SAMPLES_DIR', File.expand_path('../../sample-events', __dir__))

# Stand-in for the broker exchange: records what the publisher would send,
# matching Bunny::Exchange#publish(payload, opts = {}).
class CapturingExchange
  attr_reader :messages

  def initialize
    @messages = []
  end

  def publish(payload, opts = {})
    @messages << { payload: payload, opts: opts }
  end
end

CapturingConnection = Struct.new(:exchange)

validator = Validator.new(SPEC_PATH)
exchange = CapturingExchange.new
publisher = Publisher.new(CapturingConnection.new(exchange), validator)

# The representative messages this provider publishes are the valid sample events.
samples = Dir["#{SAMPLES_DIR}/*.json"]
          .reject { |f| File.basename(f).start_with?('invalid') }
          .sort

failures = 0
samples.each do |path|
  name = File.basename(path)
  event = JSON.parse(File.read(path))
  begin
    publisher.publish(event) # validates against the contract, then "publishes"
    published = JSON.parse(exchange.messages.last[:payload])
    errors = validator.errors_for(published)
    if errors.empty?
      puts "✓ #{name} → publishes a contract-valid MusicEventPublished"
    else
      failures += 1
      warn "✗ #{name} → published message violates the contract:"
      errors.each { |e| warn "    - #{e}" }
    end
  rescue ArgumentError => e
    failures += 1
    warn "✗ #{name} → publisher refused (does not conform): #{e.message}"
  end
end

puts
if failures.zero?
  puts "PROVIDER SELF-VERIFICATION PASSED — #{samples.size} message(s) conform to asyncapi.yaml"
  exit 0
else
  warn "PROVIDER SELF-VERIFICATION FAILED — #{failures} of #{samples.size} message(s) violate the contract"
  exit 1
end
