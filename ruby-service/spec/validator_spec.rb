# frozen_string_literal: true

RSpec.describe Validator do
  subject(:validator) { described_class.new(SPEC_PATH) }

  it 'accepts a valid event' do
    expect(validator.errors_for(load_sample('london-jazz'))).to be_empty
    expect(validator).to be_valid(load_sample('london-jazz'))
  end

  it 'accepts an event without the optional price/endsAt fields' do
    expect(validator.errors_for(load_sample('berlin-techno'))).to be_empty
  end

  it 'rejects an event that breaks the contract, reporting every violation' do
    errors = validator.errors_for(load_sample('invalid-london-jazz'))
    expect(errors).not_to be_empty
    expect(errors.join("\n")).to match(/title/)          # missing required property
    expect(errors.join("\n")).to match(%r{/location/country}) # country longer than 2 chars
    expect(errors.join("\n")).to match(%r{/startsAt})    # not a date-time
  end

  it 'rejects an unknown genre (enum)' do
    event = load_sample('london-jazz').merge('genre' => 'polka')
    expect(validator.errors_for(event).join).to match(/genre|enum/)
  end

  it 'rejects unknown top-level properties (additionalProperties: false)' do
    event = load_sample('london-jazz').merge('surprise' => true)
    expect(validator.valid?(event)).to be(false)
  end
end
