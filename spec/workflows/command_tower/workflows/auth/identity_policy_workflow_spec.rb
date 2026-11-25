# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::IdentityPolicyWorkflow do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:plain_text) { CommandTower.config.login.plain_text }
    let(:username) { CommandTower.config.username }
    let(:email_verify) { plain_text.email_verify }

    it "returns the camelCase identity policy payload" do
      expect(result).to be_success
      expect(result.http_status).to eq(:ok)
      expect(result.payload[:password]).to include(
        minLength: plain_text.password_length_min,
        maxLength: plain_text.password_length_max,
        maxBytes: 72
      )
      expect(result.payload[:email]).to include(
        minLength: plain_text.email_length_min,
        maxLength: plain_text.email_length_max
      )
      expect(result.payload[:username]).to include(
        minLength: username.username_length_min,
        maxLength: username.username_length_max,
        pattern: "^\\w{#{username.username_length_min},#{username.username_length_max}}$",
        patternDescription: username.username_failure_message,
        selfService: false,
        selfChange: false,
        prompt: "after_signup"
      )
      expect(result.payload).to include(
        verificationCode: {
          length: email_verify.verify_code_length,
          characterSet: "numeric"
        },
        phoneVerificationCode: {
          length: CommandTower.config.identity.phone_verification.verify_code_length,
          characterSet: "numeric"
        }
      )
    end

    context "when the policy service fails" do
      before do
        allow(CommandTower::Services::Auth::IdentityPolicy).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [CommandTower::Errors::InternalError.new])
        )
      end

      it "returns internal_server_error" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:internal_server_error)
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::InternalError))
      end
    end
  end
end
