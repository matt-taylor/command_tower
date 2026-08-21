# frozen_string_literal: true

RSpec.describe CommandTower::Errors::ContinuationExhaustedError do
  subject(:error) { described_class.new(details: { attempt: 24, max_attempts: 24 }) }

  it { expect(error.code).to eq("continuation_exhausted") }
  it { expect(error.message).to include("24") }
end
