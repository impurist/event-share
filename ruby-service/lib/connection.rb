# frozen_string_literal: true

require 'bunny'

# Thin wrapper around a Bunny connection that declares the shared topic exchange.
# Retries the initial connection so the service can start before the broker is
# accepting connections (e.g. under docker-compose, where a healthcheck can pass
# moments before the AMQP listener is ready).
class Connection
  attr_reader :channel, :exchange

  def initialize(url: ENV.fetch('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672'),
                 max_attempts: 30, retry_delay: 2)
    @conn = connect_with_retry(url, max_attempts, retry_delay)
    @channel = @conn.create_channel
    @exchange = @channel.topic(Routing::EXCHANGE, durable: true, auto_delete: false)
  end

  def close
    @conn.close
  end

  private

  def connect_with_retry(url, max_attempts, retry_delay)
    attempt = 0
    begin
      attempt += 1
      conn = Bunny.new(url, automatically_recover: true)
      conn.start
      conn
    rescue Bunny::TCPConnectionFailed, Bunny::HostListDepleted => e
      raise if attempt >= max_attempts

      warn "[ruby-service] broker not ready (attempt #{attempt}/#{max_attempts}): " \
           "#{e.message} — retrying in #{retry_delay}s"
      sleep retry_delay
      retry
    end
  end
end
