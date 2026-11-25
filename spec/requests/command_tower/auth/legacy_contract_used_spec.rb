# frozen_string_literal: true

RSpec.describe "auth.legacy_contract_used events", type: :request do
  let(:client_headers) { { "X-App-Version" => "1.2.3", "X-Client-Platform" => "ios" } }
  let(:subscription) { capture_notifications("command_tower.auth.legacy_contract_used") }
  let(:endpoints) { subscription.first.map { |event| event[:payload][:endpoint] } }

  before do
    flush_signup_rate_limits!
    flush_password_recovery_rate_limits!
    subscription
  end

  after { unsubscribe_notifications(subscription.last) }

  describe "deprecated endpoints" do
    it "records signup-session with the endpoint, app version and platform only" do
      post "/auth/signup-session", headers: client_headers

      expect(subscription.first.map { |event| event[:payload].slice(:endpoint, :app_version, :platform) }).to eq(
        [{ endpoint: "signup_session", app_version: "1.2.3", platform: "ios" }]
      )
    end

    it "records password-recovery-session" do
      post "/auth/password-recovery-session", headers: client_headers

      expect(endpoints).to eq(["password_recovery_session"])
    end

    context "with a Signup session" do
      let(:signup_headers) { signup_session_headers(create_signup_session!["signupSessionToken"]) }

      before do
        signup_headers
        subscription.first.clear
      end

      it "records the email availability endpoint and the Signup scheme" do
        get "/auth/email/availability", params: { email: "newmember@example.com" }, headers: signup_headers

        expect(endpoints).to eq(%w[email_availability authorization_scheme.signup])
      end

      it "records the username availability endpoint and the Signup scheme" do
        get "/auth/username/availability", params: { username: "newmember" }, headers: signup_headers

        expect(endpoints).to eq(%w[username_availability authorization_scheme.signup])
      end
    end

    it "records an availability call that sends no Signup session without the scheme" do
      get "/auth/email/availability", params: { email: "newmember@example.com" }

      expect(endpoints).to eq(["email_availability"])
    end
  end

  describe "register shape" do
    let(:password) { "Correct-Horse-9-Battery" }

    it "records the old six-field shape" do
      post "/auth/register",
           params: { first_name: "Ada", last_name: "Lovelace", username: "ada_l", email: "ada-old@example.com",
                     password:, password_confirmation: password },
           as: :json

      expect(endpoints).to eq(["register_old_shape"])
    end

    it "does not record the new shape" do
      post "/auth/register", params: { email: "ada-new@example.com", password:, start_session: true }, as: :json

      expect(endpoints).to be_empty
    end
  end

  describe "Recovery scheme" do
    let(:recovery_headers) do
      session = create_password_recovery_session!(client_ip: "203.0.113.5")
      password_recovery_session_headers(session["recoverySessionToken"], client_ip: "203.0.113.5")
    end

    before do
      recovery_headers
      subscription.first.clear
    end

    it "is recorded when a recovery session authenticates" do
      post "/auth/password-reset/send", params: { email: "someone@example.com" }, headers: recovery_headers, as: :json

      expect(endpoints).to eq(["authorization_scheme.recovery"])
    end
  end

  describe "sid-less tokens" do
    let(:user) { create(:user) }

    it "records a valid sid-less token" do
      CommandTower::Jwt::AuthenticateUser.call(token: CommandTower::Jwt::LoginCreate.call(user:).token)

      expect(endpoints).to eq(["sidless_token"])
    end

    context "with an expired token" do
      let(:expired_token) do
        stale = (Time.current - CommandTower.config.jwt.ttl - 1.hour).to_i
        payload = { generated_at: stale, user_id: user.id, verifier_token: user.retreive_verifier_token! }
        CommandTower::Jwt::Encode.call(payload:)
      end

      it "does not record it" do
        CommandTower::Jwt::AuthenticateUser.call(token: expired_token)

        expect(endpoints).to be_empty
      end
    end

    context "with a session token" do
      let(:session_token) do
        CommandTower::Jwt::LoginCreate.call(user:, device_session: create(:device_session, user:)).token
      end

      it "does not record it" do
        CommandTower::Jwt::AuthenticateUser.call(token: session_token)

        expect(endpoints).to be_empty
      end
    end
  end
end
