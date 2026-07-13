# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::PasswordReset::Validate do
  let(:user) { create(:user) }
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

  describe ".call" do
    subject(:call) { described_class.(token: token, email: email) }

    let(:email) { nil }

    context "with valid token" do
      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets valid to true" do
        expect(call.valid).to eq(true)
      end

      it "sets expires_at" do
        expect(call.expires_at).to be_present
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

        it "sets valid to true" do
          expect(call.valid).to eq(true)
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets valid to true" do
          expect(call.valid).to eq(true)
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

        it "sets valid to true" do
          expect(call.valid).to eq(true)
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

    context "with used token (used for reset)" do
      before do
        # Use the token for reset (increments use_count to 1, which exceeds use_count_max of 1)
        # Actually, with use_count_max: 1, use_count: 1 is still valid (1 <= 1)
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
  end
end
