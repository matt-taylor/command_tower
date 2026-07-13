# frozen_string_literal: true

RSpec.describe CommandTower::LoginStrategy::PlainText::ChangePassword do
  # Sentinel values must never appear in msgs, hashes, returned payloads, or exception text
  SENTINEL_CURRENT = "SentinelCurrentPassword_Aa1!"
  SENTINEL_NEW = "SentinelNewPassword_Bb2!"
  SENTINEL_WRONG = "SentinelWrongPassword_Cc3!"

  let(:user) { create(:user, password: SENTINEL_CURRENT, password_confirmation: SENTINEL_CURRENT) }
  let(:current_password) { SENTINEL_CURRENT }
  let(:password) { SENTINEL_NEW }
  let(:password_confirmation) { password }

  describe ".call" do
    subject(:call) do
      described_class.(
        user: user,
        current_password: current_password,
        password: password,
        password_confirmation: password_confirmation
      )
    end

    def assert_no_secret_leak!(result)
      serialized = [
        result.msg,
        result.message,
        result.try(:invalid_argument_hash)&.inspect,
        result.try(:invalid_argument_keys)&.inspect,
      ].compact.join(" ")

      expect(serialized).not_to include(SENTINEL_CURRENT)
      expect(serialized).not_to include(SENTINEL_NEW)
      expect(serialized).not_to include(SENTINEL_WRONG)
      expect(serialized).not_to include(user.reload.verifier_token) if user.verifier_token.present?
    end

    context "with valid current password and matching new passwords" do
      let!(:old_verifier) { user.retreive_verifier_token! }
      let!(:old_jwt) { CommandTower::Jwt::LoginCreate.(user: user.reload).token }

      it "succeeds" do
        expect(call.success?).to eq(true)
        assert_no_secret_leak!(call)
      end

      it "sets message" do
        expect(call.message).to eq("Password has been successfully changed")
        assert_no_secret_leak!(call)
      end

      it "does not return a JWT or verifier" do
        call
        expect(call.try(:token)).to be_nil
        expect(call.respond_to?(:verifier_token) ? call.verifier_token : nil).to be_nil
        assert_no_secret_leak!(call)
      end

      it "updates user password" do
        call
        expect(user.reload.authenticate(SENTINEL_NEW)).to be_truthy
      end

      it "invalidates old password" do
        call
        expect(user.reload.authenticate(SENTINEL_CURRENT)).to be_falsey
      end

      it "rotates verifier_token" do
        call
        expect(user.reload.verifier_token).not_to eq(old_verifier)
      end

      it "invalidates existing JWT sessions" do
        call
        auth = CommandTower::Jwt::AuthenticateUser.(token: old_jwt)
        expect(auth.failure?).to eq(true)
      end

      it "allows login with the new password" do
        call
        login = CommandTower::LoginStrategy::PlainText::Login.(
          identifier: user.email,
          password: SENTINEL_NEW
        )
        expect(login.success?).to eq(true)
      end

      it "rejects login with the old password" do
        call
        login = CommandTower::LoginStrategy::PlainText::Login.(
          identifier: user.email,
          password: SENTINEL_CURRENT
        )
        expect(login.failure?).to eq(true)
      end
    end

    context "with incorrect current password" do
      let(:current_password) { SENTINEL_WRONG }
      let!(:old_digest) { user.password_digest }
      let!(:old_verifier) { user.retreive_verifier_token! }

      it "fails with invalid_arguments" do
        expect(call.failure?).to eq(true)
        expect(call.invalid_arguments).to eq(true)
        expect(call.invalid_argument_hash).to include(
          current_password: hash_including(msg: "Incorrect current password")
        )
        assert_no_secret_leak!(call)
      end

      it "does not mutate password or verifier" do
        call
        user.reload
        expect(user.password_digest).to eq(old_digest)
        expect(user.verifier_token).to eq(old_verifier)
      end
    end

    context "with password confirmation mismatch" do
      let(:password_confirmation) { SENTINEL_WRONG }
      let!(:old_digest) { user.password_digest }
      let!(:old_verifier) { user.retreive_verifier_token! }

      it "fails with invalid_arguments" do
        expect(call.failure?).to eq(true)
        expect(call.invalid_arguments).to eq(true)
        expect(call.invalid_argument_hash).to include(
          password_confirmation: hash_including(msg: "Password and confirmation do not match")
        )
        assert_no_secret_leak!(call)
      end

      it "does not mutate password or verifier" do
        call
        user.reload
        expect(user.password_digest).to eq(old_digest)
        expect(user.verifier_token).to eq(old_verifier)
      end
    end

    context "with password too short" do
      let(:password) { "short" }
      let(:password_confirmation) { "short" }
      let!(:old_digest) { user.password_digest }
      let!(:old_verifier) { user.retreive_verifier_token! }

      it "fails with invalid_arguments" do
        expect(call.failure?).to eq(true)
        expect(call.invalid_arguments).to eq(true)
        assert_no_secret_leak!(call)
      end

      it "does not mutate password or verifier" do
        call
        user.reload
        expect(user.password_digest).to eq(old_digest)
        expect(user.verifier_token).to eq(old_verifier)
      end
    end

    context "when password save succeeds but verifier rotation fails" do
      let!(:old_digest) { user.password_digest }
      let!(:old_verifier) { user.retreive_verifier_token! }

      before do
        allow_any_instance_of(User).to receive(:reset_verifier_token!).and_raise(StandardError, "simulated verifier failure")
      end

      it "fails with typed infrastructure failure" do
        expect(call.failure?).to eq(true)
        expect(call.msg).to eq("Failed to rotate session verifier")
        expect(call.status).to eq(500)
        expect(call.invalid_arguments).not_to eq(true)
        assert_no_secret_leak!(call)
      end

      it "rolls back password and verifier" do
        call
        user.reload
        expect(user.password_digest).to eq(old_digest)
        expect(user.verifier_token).to eq(old_verifier)
        expect(user.authenticate(SENTINEL_CURRENT)).to be_truthy
        expect(user.authenticate(SENTINEL_NEW)).to be_falsey
      end
    end

    context "when password save fails" do
      let!(:old_digest) { user.password_digest }
      let!(:old_verifier) { user.retreive_verifier_token! }

      before do
        allow(user).to receive(:save).and_return(false)
        errors = ActiveModel::Errors.new(user)
        errors.add(:password, "is invalid")
        allow(user).to receive(:errors).and_return(errors)
      end

      it "fails with invalid_arguments" do
        expect(call.failure?).to eq(true)
        expect(call.invalid_arguments).to eq(true)
        assert_no_secret_leak!(call)
      end

      it "does not rotate verifier" do
        call
        expect(user.reload.verifier_token).to eq(old_verifier)
      end
    end

    context "with missing required arguments" do
      it "fails when current_password is missing" do
        result = described_class.(
          user: user,
          current_password: nil,
          password: password,
          password_confirmation: password_confirmation
        )
        expect(result.failure?).to eq(true)
        expect(result.invalid_arguments).to eq(true)
        assert_no_secret_leak!(result)
      end
    end
  end
end
