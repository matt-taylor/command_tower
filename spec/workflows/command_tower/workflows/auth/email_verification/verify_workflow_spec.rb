# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::EmailVerification::VerifyWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user, input: input) }

    let(:input) { CommandTower::Deserializers::Auth::EmailVerification::VerifyDeserializer::Input.new(code: code) }

    context "with a valid code" do
      let(:user) { create(:user, :unvalidated_email) }
      let(:code) do
        CommandTower::Secrets::Generate.call(
          user: user,
          secret_length: 6,
          reason: CommandTower::Secrets::EMAIL_VERIFICIATION,
          use_count_max: 1,
          death_time: 10.minutes,
          type: CommandTower::Secrets::NUMERIC,
          cleanse: true
        ).secret
      end

      it { expect(result).to be_success }
      it { expect(result.http_status).to eq(:created) }

      it "serializes the message" do
        expect(result.payload).to eq(message: "Successfully verified email")
      end
    end

    context "with an incorrect code" do
      let(:user) { create(:user, :unvalidated_email) }
      let(:code) { "000000" }

      it "fails with unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::VerificationCodeInvalidError)
      end
    end

    context "when the email is already verified" do
      let(:user) { create(:user) }
      let(:code) { "000000" }

      it "is idempotent with ok" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:message]).to include("already verified")
      end
    end
  end
end
