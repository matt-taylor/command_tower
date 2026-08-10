# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::PasswordReset::ValidateDeserializer do
  describe ".call" do
    subject(:deserialized) { described_class.call(params) }

    context "with a token only" do
      let(:params) { { token: " abc123 " } }

      it { expect(deserialized).to be_success }
      it { expect(deserialized.input.token).to eq("abc123") }
      it { expect(deserialized.input.email).to be_nil }
    end

    context "with a token and email" do
      let(:params) { { token: "abc123", email: " User@Example.com " } }

      it { expect(deserialized.input.email).to eq("user@example.com") }
    end

    context "without a token" do
      let(:params) { { email: "user@example.com" } }

      it { expect(deserialized).to be_failure }
      it { expect(deserialized.errors).to eq([{ token: "Token is required" }]) }
    end
  end
end
