# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::UsernameAvailabilityDeserializer do
  describe "#call" do
    subject(:result) { described_class.call(params) }

    context "when username is present" do
      let(:params) { { username: "adalove" } }

      it "returns success input" do
        expect(result).to be_success
        expect(result.input.username).to eq("adalove")
      end
    end

    context "when username includes surrounding whitespace" do
      let(:params) { { username: "  adalove  " } }

      it "strips whitespace" do
        expect(result).to be_success
        expect(result.input.username).to eq("adalove")
      end
    end

    context "when username is missing" do
      let(:params) { {} }

      it { is_expected.to be_failure }
    end

    context "when username is blank after normalization" do
      let(:params) { { username: "   " } }

      it { is_expected.to be_failure }
    end
  end
end
