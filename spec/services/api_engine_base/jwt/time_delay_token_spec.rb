# frozen_string_literal: true

RSpec.describe ApiEngineBase::Jwt::TimeDelayToken do
  describe ".call" do
    subject(:call) { described_class.(expires_in:) }
    let(:expires_in) { 5.minutes }

    it "returns a token" do
      expect(call.token).to be_a(String)
    end
  end
end
