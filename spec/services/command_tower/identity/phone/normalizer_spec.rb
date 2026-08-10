# frozen_string_literal: true

RSpec.describe CommandTower::Identity::Phone::Normalizer do
  describe ".call" do
    subject(:call) { described_class.call(phone_number:) }

    context "with a valid E.164 number" do
      let(:phone_number) { "+1 (415) 555-2671" }

      it "succeeds" do
        expect(call).to be_success
      end

      it "normalizes to E.164" do
        expect(call.normalized).to eq("+14155552671")
      end
    end

    context "with a US national number without +" do
      let(:phone_number) { "4155552671" }

      it "normalizes using default country US" do
        expect(call).to be_success
        expect(call.normalized).to eq("+14155552671")
      end
    end

    context "with blank input" do
      let(:phone_number) { "   " }

      it "fails" do
        expect(call).to be_failure
      end

      it "explains that a number is required" do
        expect(call.message).to eq(described_class::BLANK_MESSAGE)
        expect(call.normalized).to be_nil
      end
    end

    context "with unparseable input" do
      let(:phone_number) { "not-a-phone" }

      it "fails" do
        expect(call).to be_failure
      end

      it "explains that the number is invalid" do
        expect(call.message).to eq(described_class::INVALID_MESSAGE)
        expect(call.normalized).to be_nil
      end
    end
  end
end
