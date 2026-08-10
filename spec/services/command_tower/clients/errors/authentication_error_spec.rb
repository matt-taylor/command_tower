# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Errors::AuthenticationError do
  describe "#code" do
    subject(:code) { described_class.new.code }

    it { is_expected.to eq("authentication_error") }
  end

  describe "#message" do
    context "when a custom message is provided" do
      subject(:message) { described_class.new(message: "missing token").message }

      it { is_expected.to eq("missing token") }
    end

    context "when no message is provided" do
      subject(:message) { described_class.new.message }

      it { is_expected.to eq("Client authentication failed") }
    end
  end
end
