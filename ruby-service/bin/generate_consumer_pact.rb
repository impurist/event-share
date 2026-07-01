#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates this service's CONSUMER message pact for Bi-Directional Contract Testing.
#
# ruby-service (consumer / subscriber) declares the MusicEventPublished message it
# expects from provider ts-service, runs the example through its REAL handler
# (Subscriber#classify), and — only if the handler accepts it — writes a Pact v3
# message pact to ./pacts.
#
# NOTE: Ruby's official message DSL (pact-message-ruby) is unmaintained and its
# consumer side is undocumented, so we emit a spec-compliant Pact v4 message pact
# directly (Asynchronous/Messages). The structure mirrors the pact-js v4 output
# (see ts-service/test/pact) so PactFlow ingests both identically. Swap in the DSL
# later if it gains v4 support.

require 'json'
require 'fileutils'
require_relative '../boot'

CONSUMER = 'event-share-broker-service'
PROVIDER = 'event-share-user-service'
SPEC_PATH = ENV.fetch('SPEC_PATH', File.expand_path('../../asyncapi.yaml', __dir__))
PACTS_DIR = ENV.fetch('PACTS_DIR', File.expand_path('../pacts', __dir__))

# The example message and the fields this consumer relies on (type-matched).
contents = {
  'id' => '3f1a8c2e-9b7d-4e6a-bc11-2f0d4a9e7c01',
  'title' => 'Midnight Quartet — Live',
  'artist' => 'The Blue Notes',
  'genre' => 'jazz',
  'location' => { 'city' => 'london', 'venue' => "Ronnie Scott's", 'country' => 'GB' },
  'startsAt' => '2026-07-12T20:00:00Z',
  'submittedBy' => 'user_42',
  'submittedAt' => '2026-06-30T09:00:00Z'
}

type_matcher_paths = [
  '$.id', '$.title', '$.artist', '$.genre',
  '$.location', '$.location.city', '$.location.venue', '$.location.country',
  '$.startsAt', '$.submittedBy', '$.submittedAt'
]

# Run the example through the REAL consumer handler. The pact is only valid if
# the consumer can actually process the message.
validator = Validator.new(SPEC_PATH)
subscriber = Subscriber.new(nil, validator, pattern: 'events.#')
result = subscriber.classify(JSON.generate(contents))
unless result.status == :valid
  warn "✗ consumer cannot process its own expected message: #{result.errors.join('; ')}"
  exit 1
end

matching_rules = type_matcher_paths.each_with_object({}) do |path, rules|
  rules[path] = { 'combine' => 'AND', 'matchers' => [{ 'match' => 'type' }] }
end

# Pact Specification v4 — an Asynchronous/Messages interaction (mirrors pact-js v4).
pact = {
  'consumer' => { 'name' => CONSUMER },
  'provider' => { 'name' => PROVIDER },
  'interactions' => [
    {
      'type' => 'Asynchronous/Messages',
      'description' => 'a MusicEventPublished event',
      'pending' => false,
      'contents' => {
        'content' => contents,
        'contentType' => 'application/json',
        'encoded' => false
      },
      'matchingRules' => { 'body' => matching_rules },
      'metadata' => {
        'contentType' => 'application/json'
      },
      # Links this interaction to the AsyncAPI operation it consumes, so PactFlow
      # can cross-validate it against the provider's AsyncAPI contract.
      'comments' => {
        'references' => {
          'AsyncAPI' => { 'operation' => 'publishMusicEvent' }
        }
      }
    }
  ],
  'metadata' => {
    'pactSpecification' => { 'version' => '4.0' }
  }
}

FileUtils.mkdir_p(PACTS_DIR)
out = File.join(PACTS_DIR, "#{CONSUMER}-#{PROVIDER}.json")
File.write(out, "#{JSON.pretty_generate(pact)}\n")
puts "✓ wrote consumer pact: #{out}  (#{CONSUMER} → #{PROVIDER})"
