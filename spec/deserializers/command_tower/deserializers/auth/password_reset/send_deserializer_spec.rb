# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::PasswordReset::SendDeserializer do
  describe ".call" do
    subject(:deserialized) { described_class.call(params) }

    context "with an email" do
      let(:params) { { email: "  Reset@Example.COM " } }

      it { expect(deserialized).to be_success }
      it { expect(deserialized.input.email).to eq("reset@example.com") }
    end

    context "without an email" do
      let(:params) { {} }

      it { expect(deserialized).to be_failure }
      it { expect(deserialized.errors).to eq([{ email: "Email is required" }]) }
    end
  end
end
