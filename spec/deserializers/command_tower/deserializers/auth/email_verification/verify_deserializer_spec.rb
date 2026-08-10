# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::EmailVerification::VerifyDeserializer do
  describe ".call" do
    subject(:deserialized) { described_class.call(params) }

    context "with a code" do
      let(:params) { { code: " 123456 " } }

      it { expect(deserialized).to be_success }
      it { expect(deserialized.input.code).to eq("123456") }
    end

    context "without a code" do
      let(:params) { {} }

      it { expect(deserialized).to be_failure }
      it { expect(deserialized.errors).to eq([{ message: "missing_code" }]) }
    end

    context "with a blank code" do
      let(:params) { { code: "   " } }

      it { expect(deserialized).to be_failure }
    end
  end
end
