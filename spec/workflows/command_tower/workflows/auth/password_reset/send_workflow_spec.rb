# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::PasswordReset::SendWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(input: input, password_recovery_session: session)
    end

    let(:input) { CommandTower::Deserializers::Auth::PasswordReset::SendDeserializer::Input.new(email: email) }
    let(:email) { "reset-flow@example.com" }
    let(:session) { password_recovery_session_context }

    before do
      flush_password_recovery_rate_limits!
      ActionMailer::Base.deliveries.clear
    end

    context "with a known email" do
      let!(:user) { create(:user, email: email) }

      it { expect(result).to be_success }
      it { expect(result.http_status).to eq(:ok) }

      it "returns the non-enumerating message" do
        expect(result.payload[:message]).to eq(
          "If an account exists with that email, a password reset link has been sent."
        )
      end
    end

    context "with an unknown email" do
      it "returns the same message and status" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:message]).to eq(
          "If an account exists with that email, a password reset link has been sent."
        )
      end
    end

    context "when the session send budget is exhausted" do
      before do
        CommandTower.config.password_recovery_session.rate_limits.jti_send.times do
          described_class.call(input: input, password_recovery_session: session)
        end
      end

      it "fails with too_many_requests" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionRateLimitError)
      end
    end

    context "when password reset is disabled" do
      before do
        CommandTower.configure do |config|
          config.login.plain_text.password_reset.enabled = false
        end
      end

      after do
        CommandTower.configure do |config|
          config.login.plain_text.password_reset.enabled = true
        end
      end

      it "fails with service_unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetUnavailableError)
      end
    end
  end
end
