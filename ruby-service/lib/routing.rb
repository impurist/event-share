# frozen_string_literal: true

module Routing
  EXCHANGE = 'music.events'

  # Slugify a value the SAME way the TypeScript service does (see ts-service/src/routing.ts):
  # lowercase, replace any run of non-alphanumeric characters with a single '-',
  # and strip leading/trailing '-'. This keeps the routing key free of '.' so it
  # never breaks AMQP topic word boundaries.
  def self.slug(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
  end

  # Build the topic routing key for an event: events.<city>.<genre>
  def self.routing_key_for(event)
    city = slug(event.dig('location', 'city'))
    genre = slug(event['genre'])
    "events.#{city}.#{genre}"
  end
end
