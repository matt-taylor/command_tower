# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::AuthenticateRequestWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(request: request, response: response) }

    let(:response) { ActionDispatch::Response.new }
    let(:jwt_cookie_name) { CommandTower.config.jwt.cookie.name }

    context "with a valid Bearer token" do
      let!(:user) { create(:user) }
      let(:request) { build_auth_rack_request(path: "/auth/session", headers: { authorization: "Bearer #{login_token_for(user)}" }) }

      it { expect(result).to be_success }
      it { expect(result.http_status).to eq(:ok) }

      it "returns the current user and auth context" do
        expect(result.payload[:current_user]).to eq(user)
        expect(result.payload[:auth_context]).to be_a(CommandTower::Auth::AuthContext)
        expect(result.payload[:auth_context].token_source).to eq(:header)
      end

      it "asks for no transport effects" do
        expect(result.response_effects).to be_nil
      end
    end

    context "without a token" do
      let(:request) { build_auth_rack_request(path: "/auth/session") }

      it "fails with unauthorized" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors.first).to be_a(CommandTower::Errors::UnauthorizedError)
      end

      it "asks for no cookie clearing" do
        expect(result.response_effects).to be_nil
      end
    end

    context "with an unverified email over cookie" do
      let!(:user) { create(:user, :unvalidated_email) }
      let(:request) do
        build_auth_rack_request(path: "/auth/session", cookies: { jwt_cookie_name => login_token_for(user) })
      end

      before do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = true
        end
      end

      after do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = false
        end
      end

      it "fails with precondition_failed and keeps the auth cookie" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:precondition_failed)
        expect(result.response_effects).to be_nil
      end
    end

    context "when the caller bypasses email validation" do
      subject(:result) do
        described_class.call(request: request, response: response, bypass_email_validation: true)
      end

      let!(:user) { create(:user, :unvalidated_email) }
      let(:request) { build_auth_rack_request(path: "/auth/session", headers: { authorization: "Bearer #{login_token_for(user)}" }) }

      it "authenticates the unverified user" do
        expect(result).to be_success
        expect(result.payload[:current_user]).to eq(user)
      end
    end

    context "with a failed cookie authentication" do
      let(:request) do
        build_auth_rack_request(path: "/auth/session", cookies: { jwt_cookie_name => "invalid-token" })
      end

      before do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = true
        end
      end

      after do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = false
        end
      end

      it "asks the renderer to clear the auth cookie" do
        expect(result).to be_failure
        expect(result.response_effects).to eq(clear_auth_cookie: true)
      end
    end
  end
end
