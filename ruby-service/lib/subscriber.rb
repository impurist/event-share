# frozen_string_literal: true

require 'json'

# Binds a queue to the topic exchange with a routing-key pattern and consumes
# matching events, validating each one against the AsyncAPI contract.
class Subscriber
  # Outcome of inspecting a single message body.
  # status is one of :valid, :invalid, :unparseable.
  Result = Struct.new(:status, :payload, :errors)

  def initialize(connection, validator, pattern:, service_name: 'ruby-service')
    @connection = connection
    @validator = validator
    @pattern = pattern
    @service_name = service_name
  end

  def run
    queue = @connection.channel.queue("#{@service_name}.events", durable: true)
    queue.bind(@connection.exchange, routing_key: @pattern)

    puts "[#{@service_name}] ✓ subscribed — queue '#{queue.name}' bound to '#{@pattern}'"
    puts "[#{@service_name}]   waiting for music events… (Ctrl+C to exit)"

    queue.subscribe(manual_ack: true, block: true) do |delivery_info, _props, body|
      handle(delivery_info, body)
    end
  end

  # Inspect a raw message body and classify it against the contract.
  # Pure (no broker / no I/O) so it can be unit-tested directly.
  def classify(body)
    payload = JSON.parse(body)
    errors = @validator.errors_for(payload)
    Result.new(errors.empty? ? :valid : :invalid, payload, errors)
  rescue JSON::ParserError => e
    Result.new(:unparseable, nil, [e.message])
  end

  private

  def handle(delivery_info, body)
    routing_key = delivery_info.routing_key
    result = classify(body)

    case result.status
    when :valid
      loc = result.payload['location'] || {}
      puts "[#{@service_name}] ← received #{routing_key} ✓ valid — " \
           "#{result.payload['title']} · #{result.payload['artist']} @ #{loc['venue']}, #{loc['city']}"
    when :invalid
      warn "[#{@service_name}] ← received #{routing_key} ✗ INVALID — does not match contract:"
      result.errors.each { |e| warn "[#{@service_name}]     - #{e}" }
    when :unparseable
      warn "[#{@service_name}] ← received #{routing_key} ✗ unparseable JSON: #{result.errors.first}"
    end

    @connection.channel.ack(delivery_info.delivery_tag)
  end
end
