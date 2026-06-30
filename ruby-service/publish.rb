#!/usr/bin/env ruby
# frozen_string_literal: true

# Publish one or more music events from JSON files.
#
#   ruby publish.rb [--force] <event.json> [<event2.json> ...]
#
#   --force   publish even if the event fails the AsyncAPI contract
#             (useful for demonstrating consumer-side validation)

require 'json'
require_relative 'boot'

SPEC_PATH = ENV.fetch('SPEC_PATH', File.expand_path('../asyncapi.yaml', __dir__))

args = ARGV.dup
force = args.delete('--force') ? true : false

if args.empty?
  warn 'usage: ruby publish.rb [--force] <event.json> [<event.json> ...]'
  exit 64
end

validator = Validator.new(SPEC_PATH)
connection = Connection.new
publisher = Publisher.new(connection, validator)

exit_code = 0
args.each do |path|
  event = JSON.parse(File.read(path))
  publisher.publish(event, force: force)
rescue ArgumentError => e
  warn "[ruby-service] ✗ refused #{File.basename(path)}: #{e.message}"
  exit_code = 1
rescue Errno::ENOENT
  warn "[ruby-service] ✗ no such file: #{path}"
  exit_code = 1
end

connection.close
exit exit_code
