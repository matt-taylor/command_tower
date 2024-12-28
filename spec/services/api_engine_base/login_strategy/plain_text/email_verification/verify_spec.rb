# frozen_string_literal: true

RSpec.describe ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Verify do
  let(:code) { ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Generate.(user:).secret }
  let(:user) { create(:user, :unvalidated_email) }
  let(:used_user) { user }

  describe ".call" do
    subject(:call) { described_class.(user: used_user, code:) }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets email validated" do
      expect { call }.to change { user.reload.email_validated }.from(false).to(true)
    end

    context "with incorrect code" do
      let(:code) { super() + "invalid_code" }

      it "fails" do
        expect(call.success?).to eq(false)
      end

      it "sets message" do
        expect(call.msg).to include("Incorrect verification code provided")
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end

      it "sets invalid_argument_hash" do
        expect(call.invalid_argument_hash).to include(code: {msg: /Incorrect verification code provided/})
      end

      it "sets invalid_argument_keys" do
        expect(call.invalid_argument_keys).to include(:code)
      end
    end

    context "with correct code but incorrect user" do
      let(:used_user) { create(:user, :unvalidated_email) }

      it "fails" do
        expect(call.success?).to eq(false)
      end

      it "sets message" do
        expect(call.msg).to include("Incorrect verification code provided")
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end

      it "sets invalid_argument_hash" do
        expect(call.invalid_argument_hash).to include(code: {msg: /Incorrect verification code provided/})
      end

      it "sets invalid_argument_keys" do
        expect(call.invalid_argument_keys).to include(:code)
      end
    end
  end
end
