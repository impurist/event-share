# frozen_string_literal: true

RSpec.describe Routing do
  describe '.slug' do
    it 'lowercases' do
      expect(described_class.slug('London')).to eq('london')
    end

    it 'collapses runs of non-alphanumerics into a single dash' do
      expect(described_class.slug('New York')).to eq('new-york')
      expect(described_class.slug('São  Paulo!!')).to eq('s-o-paulo')
    end

    it 'strips leading and trailing dashes' do
      expect(described_class.slug('  -Berlin- ')).to eq('berlin')
    end

    it 'never emits a dot (which would break AMQP topic word boundaries)' do
      expect(described_class.slug('a.b.c')).not_to include('.')
    end

    it 'handles nil' do
      expect(described_class.slug(nil)).to eq('')
    end
  end

  describe '.routing_key_for' do
    it 'builds events.<city>.<genre> from a real sample event' do
      event = load_sample('london-jazz')
      expect(described_class.routing_key_for(event)).to eq('events.london.jazz')
    end

    it 'slugifies multi-word cities' do
      event = { 'genre' => 'rock', 'location' => { 'city' => 'New York' } }
      expect(described_class.routing_key_for(event)).to eq('events.new-york.rock')
    end
  end
end
