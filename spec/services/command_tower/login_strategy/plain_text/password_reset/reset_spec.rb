# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::PasswordReset::Reset do
  let(:user) { create(:user, password: "old_password123") }
  let(:token) do
    result = CommandTower::Secrets::Generate.(
      user: user,
      secret_length: 32,
      reason: CommandTower::Secrets::PASSWORD_RESET,
      use_count_max: 1,
      death_time: 1.hour,
      type: CommandTower::Secrets::ALPHANUMERIC,
      cleanse: false
    )
    result.secret
  end
  let(:password) { "new_password123" }
  let(:password_confirmation) { password }
  let(:email) { nil }

  describe ".call" do
    subject(:call) { described_class.(token: token, email: email, password: password, password_confirmation: password_confirmation) }

    context "with valid token and matching passwords" do
      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets message" do
        expect(call.message).to eq("Password has been successfully reset")
      end

      it "updates user password" do
        call
        expect(user.reload.authenticate(password)).to be_truthy
      end

      it "invalidates old password" do
        call
        expect(user.reload.authenticate("old_password123")).to be_falsey
      end

      it "increments token use_count" do
        user_secret = UserSecret.find_by(secret: token)
        expect { call }.to change { user_secret.reload.use_count }.by(1)
      end
    end

    context "with password mismatch" do
      let(:password_confirmation) { "different_password" }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end

      it "sets invalid_argument_hash" do
        expect(call.invalid_argument_hash).to include(password_confirmation: hash_including(msg: "Password and confirmation do not match"))
      end
    end

    context "with password too short" do
      let(:password) { "short" }
      let(:password_confirmation) { "short" }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end
    end

    context "with invalid token" do
      let(:token) { "invalid_token_12345" }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets status to 401" do
        expect(call.status).to eq(401)
      end

      it "sets message" do
        expect(call.msg).to eq("Invalid token")
      end
    end

    context "with expired token" do
      let(:token) do
        result = CommandTower::Secrets::Generate.(
          user: user,
          secret_length: 32,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          use_count_max: 1,
          death_time: 1.hour,
          type: CommandTower::Secrets::ALPHANUMERIC,
          cleanse: false
        )
        secret = result.secret
        # Manually expire the token by setting death_time in the past
        user_secret = UserSecret.find_by(secret: secret)
        user_secret.update!(death_time: 1.hour.ago)
        secret
      end

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets status to 401" do
        expect(call.status).to eq(401)
      end

      it "sets message" do
        expect(call.msg).to eq("Invalid token")
      end
    end

    context "with used token (already used for reset)" do
      before do
        # Use the token for reset once (increments use_count to 1)
        # With use_count_max: 1, use_count: 1 is still valid (1 <= 1)
        # So we need to use it twice to make it invalid
        CommandTower::Secrets::Verify.(
          secret: token,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          access_count: true
        )
        # Use it again to exceed the max
        CommandTower::Secrets::Verify.(
          secret: token,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          access_count: true
        )
      end

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets status to 401" do
        expect(call.status).to eq(401)
      end

      it "sets message" do
        expect(call.msg).to eq("Invalid token")
      end
    end

    context "with missing token" do
      let(:token) { nil }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end
    end

    context "with missing password" do
      let(:password) { nil }

      it "fails" do
        expect(call.failure?).to eq(true)
      end

      it "sets invalid_arguments" do
        expect(call.invalid_arguments).to eq(true)
      end
    end

    context "with require_email: false (backward compatibility)" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
      end

      context "when email is not provided" do
        let(:email) { nil }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "updates user password" do
          call
          expect(user.reload.authenticate(password)).to be_truthy
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "updates user password" do
          call
          expect(user.reload.authenticate(password)).to be_truthy
        end
      end

      context "when email is provided but does not match" do
        let(:email) { "wrong@example.com" }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "sets status to 401" do
          expect(call.status).to eq(401)
        end

        it "sets message" do
          expect(call.msg).to eq("Invalid token")
        end
      end
    end

    context "with require_email: true" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(true)
      end

      context "when email is not provided" do
        let(:email) { nil }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "sets status to 400" do
          expect(call.status).to eq(400)
        end

        it "sets message" do
          expect(call.msg).to eq("Email is required")
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "updates user password" do
          call
          expect(user.reload.authenticate(password)).to be_truthy
        end
      end

      context "when email is provided but does not match" do
        let(:email) { "wrong@example.com" }

        it "fails" do
          expect(call.failure?).to eq(true)
        end

        it "sets status to 401" do
          expect(call.status).to eq(401)
        end

        it "sets message" do
          expect(call.msg).to eq("Invalid token")
        end
      end
    end

    context "with email normalization" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
      end

      context "when email has different case" do
        let(:email) { user.email.upcase }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end
      end

      context "when email has whitespace" do
        let(:email) { "  #{user.email}  " }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end
      end
    end
  end
end
