# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::EmailAvailabilityDeserializer do
  describe "#call" do
    subject(:result) { described_class.call(params) }

    context "when email is present" do
      let(:params) { { email: "USER@Example.com" } }

      it "returns success input normalized to lowercase" do
        expect(result).to be_success
        expect(result.input.email).to eq("user@example.com")
      end
    end

    context "when email includes surrounding whitespace" do
      let(:params) { { email: "  user@example.com  " } }

      it "strips whitespace" do
        expect(result).to be_success
        expect(result.input.email).to eq("user@example.com")
      end
    end

    context "when email is missing" do
      let(:params) { {} }

      it { is_expected.to be_failure }
    end

    context "when email is blank after normalization" do
      let(:params) { { email: "   " } }

      it { is_expected.to be_failure }
    end
  end
end
