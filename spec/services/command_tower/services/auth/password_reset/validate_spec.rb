# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordReset::Validate do
  describe ".call" do
    subject(:result) { described_class.call(token: token, email: email) }

    let!(:user) { create(:user, email: "validate-reset@example.com") }
    let(:email) { nil }
    let(:token) { reset_token_for.call(user) }

    let(:reset_token_for) do
      lambda do |user|
        CommandTower::Secrets::Generate.call(
          user: user,
          secret_length: CommandTower.config.login.plain_text.password_reset.token_length,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          use_count_max: 1,
          death_time: CommandTower.config.login.plain_text.password_reset.token_valid_for,
          type: CommandTower::Secrets::ALPHANUMERIC,
          cleanse: true
        ).secret
      end
    end

    context "with a live token" do
      it { expect(result).to be_success }
      it { expect(result.data[:valid]).to be(true) }
      it { expect(result.data[:expires_at]).to be_present }

      it "does not consume the token" do
        described_class.call(token: token, email: nil)

        expect(described_class.call(token: token, email: nil)).to be_success
      end
    end

    context "with an unknown token" do
      let(:token) { "not-a-real-token" }

      it "returns PasswordResetInvalidTokenError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
        )
      end
    end

    context "with an expired token" do
      before { UserSecret.find_by!(secret: token).update!(death_time: 1.hour.ago) }

      it "returns PasswordResetInvalidTokenError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
      end
    end

    context "with a token used past its budget" do
      before do
        2.times do
          CommandTower::Secrets::Verify.(
            secret: token,
            reason: CommandTower::Secrets::PASSWORD_RESET,
            access_count: true
          )
        end
      end

      it "returns PasswordResetInvalidTokenError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
      end
    end

    context "without a token" do
      let(:token) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "with an email belonging to someone else" do
      let(:email) { "someone-else@example.com" }

      it "returns PasswordResetInvalidTokenError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
      end
    end

    context "with require_email disabled" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
      end

      it "accepts a missing email" do
        expect(result).to be_success
        expect(result.data[:valid]).to be(true)
      end

      context "when the email matches" do
        let(:email) { user.email }

        it { expect(result).to be_success }
      end

      context "when the email differs only by case and whitespace" do
        let(:email) { "  #{user.email.upcase}  " }

        it { expect(result).to be_success }
      end
    end

    context "with require_email enabled" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(true)
      end

      it "returns a ValidationError naming the missing email" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to eq(email: "Email is required")
      end

      context "when the email matches" do
        let(:email) { user.email }

        it { expect(result).to be_success }
      end

      context "when the email belongs to someone else" do
        let(:email) { "wrong@example.com" }

        it "returns PasswordResetInvalidTokenError" do
          expect(result).to be_failure
          expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
        end
      end
    end
  end
end
