# frozen_string_literal: true

RSpec.describe "POST /auth/password-check", type: :request do
  subject(:make_request) { post path, params: { password: password }, as: :json }

  let(:path) { "/auth/password-check" }
  let(:plain_text) { CommandTower.config.login.plain_text }
  let(:password) { "correct-horse-battery-staple-91" }
  let(:body) { response.parsed_body }

  before { flush_signup_rate_limits! }

  context "with a valid password" do
    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "reports the password as valid" do
      expect(body["data"]).to include("valid" => true, "failures" => [], "message" => nil)
    end
  end

  context "with a too short password" do
    let(:password) { "a" * (plain_text.password_length_min - 1) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "reports too_short" do
      expect(body["data"]).to include("valid" => false, "failures" => include("too_short"))
    end

    it "returns a message" do
      expect(body["data"]["message"]).to be_present
    end
  end

  context "with a too long password" do
    let(:password) { "a" * (plain_text.password_length_max + 1) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "reports too_long" do
      expect(body["data"]).to include("valid" => false, "failures" => include("too_long"))
    end
  end

  context "without a password" do
    subject(:make_request) { post path, params: {}, as: :json }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns validation_failed" do
      expect(body["errors"].first["code"]).to eq("validation_failed")
    end

    it "names the password field" do
      expect(body["errors"].first["details"]).to eq("password" => "Password is required")
    end
  end

  context "when the per-IP limit is exceeded" do
    before do
      stub_const("CommandTower::Services::Auth::PasswordPolicy::CheckRateLimit::LIMIT_PER_MINUTE", 1)
      post path, params: { password: password }, as: :json
      make_request
    end

    it { expect(response).to have_http_status(:too_many_requests) }

    it "returns auth_rate_limited" do
      expect(body["errors"].first["code"]).to eq("auth_rate_limited")
    end
  end

  context "when Redis fails" do
    before do
      allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError)
      make_request
    end

    it { expect(response).to have_http_status(:ok) }

    it "still evaluates the password" do
      expect(body["data"]).to include("valid" => true)
    end
  end

  context "with log capture" do
    let(:password) { "Sup3r-secret-unlogged-passphrase-77" }
    let(:log_io) { StringIO.new }

    before do
      test_logger = ActiveSupport::Logger.new(log_io)
      allow(Rails).to receive(:logger).and_return(test_logger)
      allow(ActionController::Base).to receive(:logger).and_return(test_logger)
      make_request
    end

    it "never writes the password to the log" do
      expect(log_io.string).not_to include(password)
    end
  end
end
