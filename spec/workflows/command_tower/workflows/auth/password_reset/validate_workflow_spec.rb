# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::PasswordReset::ValidateWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(input: input) }

    let(:input) do
      CommandTower::Deserializers::Auth::PasswordReset::ValidateDeserializer::Input.new(token: token, email: nil)
    end
    let!(:user) { create(:user, email: "validate-flow@example.com") }

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
      let(:token) { reset_token_for.call(user) }

      it { expect(result).to be_success }
      it { expect(result.http_status).to eq(:ok) }

      it "returns validity and expiry" do
        expect(result.payload[:valid]).to be(true)
        expect(result.payload[:expiresAt]).to be_present
      end
    end

    context "with an unknown token" do
      let(:token) { "not-a-real-token" }

      it "fails with unauthorized" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordResetInvalidTokenError)
      end
    end

    context "when password reset is disabled" do
      let(:token) { reset_token_for.call(user) }

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
      end
    end
  end
end
