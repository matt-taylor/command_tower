# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::UsernameAvailabilitySerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(valid: valid, available: available, message: message) }

    let(:valid) { true }
    let(:available) { true }
    let(:message) { "Username is available" }

    it "builds the username availability shape" do
      expect(payload).to eq(
        valid: true,
        available: true,
        message: "Username is available"
      )
    end

    context "when the username is invalid and unavailable" do
      let(:valid) { false }
      let(:available) { false }
      let(:message) { "Username is invalid" }

      it "reflects the invalid state" do
        expect(payload).to eq(
          valid: false,
          available: false,
          message: "Username is invalid"
        )
      end
    end
  end
end
