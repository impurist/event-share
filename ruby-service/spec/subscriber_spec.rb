# frozen_string_literal: true

RSpec.describe Subscriber do
  let(:validator) { Validator.new(SPEC_PATH) }
  let(:connection) { double('Connection') }

  subject(:subscriber) { described_class.new(connection, validator, pattern: 'events.#') }

  describe '#classify' do
    it 'classifies a valid message body as :valid with the parsed payload' do
      result = subscriber.classify(JSON.generate(load_sample('london-jazz')))
      expect(result.status).to eq(:valid)
      expect(result.payload['title']).to eq('Midnight Quartet — Live')
      expect(result.errors).to be_empty
    end

    it 'classifies a contract-violating body as :invalid with errors' do
      result = subscriber.classify(JSON.generate(load_sample('invalid-london-jazz')))
      expect(result.status).to eq(:invalid)
      expect(result.errors).not_to be_empty
    end

    it 'classifies non-JSON as :unparseable' do
      result = subscriber.classify('{not json')
      expect(result.status).to eq(:unparseable)
      expect(result.payload).to be_nil
      expect(result.errors.first).to be_a(String)
    end
  end
end
