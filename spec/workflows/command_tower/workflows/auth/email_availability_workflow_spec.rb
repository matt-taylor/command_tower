# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::EmailAvailabilityWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(input: input, signup_session: signup_session) }

    let(:input) { CommandTower::Deserializers::Auth::EmailAvailabilityDeserializer::Input.new(email: email) }
    let(:signup_session) { signup_session_context }

    before { flush_signup_rate_limits! }

    context "with an available email" do
      let(:email) { "wf-email-available@example.com" }

      it "returns availability metadata" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload).to eq(valid: true, available: true, message: "Email is available")
      end
    end

    context "with an already-registered email" do
      let!(:user) { create(:user, email: "wf-email-taken@example.com", username: "wfemailtaken") }
      let(:email) { "wf-email-taken@example.com" }

      it "returns unavailable" do
        expect(result).to be_success
        expect(result.payload).to include(valid: true, available: false)
      end
    end

    context "with an invalid email format" do
      let(:email) { "not-an-email" }

      it "returns invalid" do
        expect(result).to be_success
        expect(result.payload).to include(valid: false, available: false)
      end
    end

    context "when the signup session is rate limited" do
      let(:email) { "wf-email-limited@example.com" }

      before do
        allow(CommandTower::Services::Auth::SignupRateLimits::CheckAvailability).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(
            errors: [CommandTower::Errors::Auth::SignupSessionRateLimitError.new]
          )
        )
      end

      it "returns too_many_requests" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionRateLimitError)
        )
      end
    end

    context "when the availability service fails" do
      let(:email) { "wf-email-broken@example.com" }

      before do
        allow(CommandTower::Services::Auth::EmailAvailability).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [CommandTower::Errors::InternalError.new])
        )
      end

      it "returns internal_server_error" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:internal_server_error)
      end
    end
  end
end
