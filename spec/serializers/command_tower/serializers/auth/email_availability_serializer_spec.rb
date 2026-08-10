# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::EmailAvailabilitySerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(valid: valid, available: available, message: message) }

    let(:valid) { true }
    let(:available) { true }
    let(:message) { "Email is available" }

    it "builds the email availability shape" do
      expect(payload).to eq(
        valid: true,
        available: true,
        message: "Email is available"
      )
    end

    context "when the email is invalid and unavailable" do
      let(:valid) { false }
      let(:available) { false }
      let(:message) { "Enter a valid email address." }

      it "reflects the invalid state" do
        expect(payload).to eq(
          valid: false,
          available: false,
          message: "Enter a valid email address."
        )
      end
    end
  end
end
