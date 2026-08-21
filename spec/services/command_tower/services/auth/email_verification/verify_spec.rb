# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::EmailVerification::Verify do
  describe ".call" do
    subject(:result) { described_class.call(user: user, code: code) }

    let(:code) { "123456" }

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

      it "reports verification" do
        expect(result.data[:message]).to eq("Successfully verified email")
      end

      it "marks the email validated" do
        result

        expect(user.reload.email_validated).to be(true)
      end

      context "when persisting the audit fact" do
        before do
          CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
            described_class.call(user: user, code: code)
          end
        end

        let(:row) { CommandTower::Audit::Event.find_by!(action: "email_verified") }

        it "persists email_verified" do
          expect(row.affected_user_id).to eq(user.id)
          expect(row.attribution_mode).to eq("self_service")
        end
      end
    end

    context "with an incorrect code" do
      let(:user) { create(:user, :unvalidated_email) }

      it "returns VerificationCodeInvalidError with field details" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::VerificationCodeInvalidError)
        expect(result.errors.first.details).to eq(code: "Incorrect verification code provided")
      end
    end

    context "when the user is already verified" do
      let(:user) { create(:user) }

      it "short circuits idempotently" do
        expect(result).to be_success
        expect(result.data[:message]).to eq("Email is already verified")
      end

      it "does not persist email_verified" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "email_verified").count }
      end
    end
  end
end
