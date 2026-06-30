# frozen_string_literal: true

require 'json'

# Validates an event against the AsyncAPI contract, then publishes it to the
# topic exchange using a routing key derived from its city + genre.
class Publisher
  def initialize(connection, validator, service_name: 'ruby-service')
    @connection = connection
    @validator = validator
    @service_name = service_name
  end

  # Returns the routing key the message was published with.
  # Raises ArgumentError if the event is invalid and force is false.
  def publish(event, force: false)
    errors = @validator.errors_for(event)
    unless errors.empty?
      message = "event fails the AsyncAPI MusicEvent contract:\n  - #{errors.join("\n  - ")}"
      raise ArgumentError, message unless force

      warn "[#{@service_name}] ⚠ publishing INVALID event anyway (--force):\n  - #{errors.join("\n  - ")}"
    end

    routing_key = Routing.routing_key_for(event)
    @connection.exchange.publish(
      JSON.generate(event),
      routing_key: routing_key,
      content_type: 'application/json',
      persistent: true,
      type: 'music.event.published',
      app_id: @service_name
    )
    puts "[#{@service_name}] → published #{routing_key}  (#{event['title'] || '?'})"
    routing_key
  end
end
