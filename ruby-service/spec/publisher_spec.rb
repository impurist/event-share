# frozen_string_literal: true

RSpec.describe Publisher do
  let(:validator) { Validator.new(SPEC_PATH) }
  let(:exchange) { instance_double('Bunny::Exchange', publish: nil) }
  let(:connection) { double('Connection', exchange: exchange) }

  subject(:publisher) { described_class.new(connection, validator) }

  describe '#publish' do
    it 'publishes a valid event with the derived routing key and returns it' do
      key = publisher.publish(load_sample('london-jazz'))

      expect(key).to eq('events.london.jazz')
      expect(exchange).to have_received(:publish).with(
        kind_of(String),
        hash_including(routing_key: 'events.london.jazz', content_type: 'application/json', persistent: true)
      )
    end

    it 'publishes the event as JSON' do
      publisher.publish(load_sample('london-rock'))
      expect(exchange).to have_received(:publish) do |body, _opts|
        expect(JSON.parse(body)).to include('title' => 'Camden Riffs', 'genre' => 'rock')
      end
    end

    it 'refuses an invalid event and does not publish' do
      expect { publisher.publish(load_sample('invalid-london-jazz')) }
        .to raise_error(ArgumentError, /MusicEvent contract/)
      expect(exchange).not_to have_received(:publish)
    end

    it 'publishes an invalid event when forced' do
      expect { publisher.publish(load_sample('invalid-london-jazz'), force: true) }.not_to raise_error
      expect(exchange).to have_received(:publish).once
    end
  end
end
