# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordReset::Reset do
  describe ".call" do
    subject(:result) do
      described_class.call(
        token: token,
        password: password,
        password_confirmation: password_confirmation,
        email: email
      )
    end

    let!(:user) { create(:user, email: "do-reset@example.com", password: "password1234") }
    let(:password) { "newpassword5678" }
    let(:password_confirmation) { password }
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

      it "reports the reset" do
        expect(result.data[:message]).to eq(described_class::RESET_MESSAGE)
      end

      it "changes the stored password" do
        result

        expect(user.reload.authenticate(password)).to be_truthy
      end

      it "invalidates the old password" do
        result

        expect(user.reload.authenticate("password1234")).to be_falsey
      end

      it "consumes the token" do
        expect { result }.to change { UserSecret.find_by(secret: token).use_count }.by(1)

        expect(described_class.call(
          token: token,
          password: "anotherpassword99",
          password_confirmation: "anotherpassword99",
          email: nil
        )).to be_failure
      end
    end

    context "with mismatched confirmation" do
      let(:password_confirmation) { "somethingelse99" }

      it "returns a ValidationError naming the confirmation field" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to eq(password_confirmation: described_class::CONFIRMATION_MISMATCH)
      end

      it "leaves the password alone" do
        result

        expect(user.reload.authenticate("password1234")).to be_truthy
      end
    end

    context "with a password below the configured minimum" do
      let(:password) { "short" }

      it "returns a ValidationError naming the password field" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to include(:password)
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

    context "without a token" do
      let(:token) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "without a password" do
      let(:password) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "with require_email disabled" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
      end

      it "accepts a missing email" do
        expect(result).to be_success
        expect(user.reload.authenticate(password)).to be_truthy
      end

      context "when the email differs only by case and whitespace" do
        let(:email) { "  #{user.email.upcase}  " }

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

        it "resets the password" do
          expect(result).to be_success
          expect(user.reload.authenticate(password)).to be_truthy
        end
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
