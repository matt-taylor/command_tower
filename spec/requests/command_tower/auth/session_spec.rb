# frozen_string_literal: true

RSpec.describe "GET /auth/session", :with_rbac_setup, type: :request do
  subject(:make_request) { get path, headers: headers }

  let(:path) { "/auth/session" }
  let(:headers) { {} }
  let(:expire_header) { CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid Bearer token" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns user and tokenExpiresAt" do
      expect(response.parsed_body["data"]["user"]).to include(
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "emailValidated" => true
      )
      expect(response.parsed_body["data"]["tokenExpiresAt"]).to be_present
    end

    it "omits impersonation when no overlay is active" do
      expect(response.parsed_body["data"]).not_to have_key("impersonation")
    end

    it "sets the expire header" do
      expect(response.headers[expire_header]).to be_present
    end
  end

  context "without a role mapped onto the action" do
    let(:user) { create(:user, roles: []) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "with X-Authorization-Reset" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) do
      authenticate_request_with_bearer!(user).merge(
        "X-Authorization-Reset" => "true"
      )
    end

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns a refreshed token header" do
      expect(response.headers["X-Authorization-Reset"]).to be_present
    end
  end

  context "with a legacy (sid-less) token" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:legacy_token) { CommandTower::Jwt::LoginCreate.call(user:).token }
    let(:headers) { { "Authorization" => "Bearer #{legacy_token}" } }
    let(:issued_token) { response.headers["X-Authorization-Reset"] }
    let(:issued_payload) { CommandTower::Jwt::Decode.call(token: issued_token).payload }

    context "when upgrade is enabled" do
      before { make_request }

      let(:row) { CommandTower::Auth::DeviceSession.find_by!(user_id: user.id) }

      it "creates one device session and issues a token carrying its sid" do
        expect(response).to have_http_status(:ok)
        expect(issued_payload[:sid]).to eq(row.public_id)
        expect(row.legacy_generated_at).to be_present
      end

      it "reuses the row on a second request with the same legacy token" do
        expect { get path, headers: headers }
          .not_to change(CommandTower::Auth::DeviceSession, :count)
        expect(CommandTower::Jwt::Decode.call(token: issued_token).payload[:sid]).to be_present
      end
    end

    context "when refreshing with X-Authorization-Reset" do
      let(:headers) { super().merge("X-Authorization-Reset" => "true") }

      before { make_request }

      it "issues the upgraded token, not a sid-less refresh" do
        expect(issued_payload[:sid]).to be_present
        expect(CommandTower::Auth::DeviceSession.where(user_id: user.id).count).to eq(1)
      end
    end

    context "when a concurrent request already created the row" do
      before do
        generated_at = CommandTower::Jwt::Decode.call(token: legacy_token).payload[:generated_at]
        create(:device_session, user:, legacy_generated_at: Time.zone.at(generated_at))
        make_request
      end

      it "converges on the single existing row" do
        expect(CommandTower::Auth::DeviceSession.where(user_id: user.id).count).to eq(1)
        expect(issued_payload[:sid]).to eq(CommandTower::Auth::DeviceSession.find_by!(user_id: user.id).public_id)
      end
    end

    context "when the upgraded row was revoked" do
      before do
        generated_at = CommandTower::Jwt::Decode.call(token: legacy_token).payload[:generated_at]
        create(:device_session, :revoked, user:, legacy_generated_at: Time.zone.at(generated_at))
        make_request
      end

      it "renders session_revoked" do
        expect(response).to have_http_status(:unauthorized)
        expect(response_error_code).to eq("session_revoked")
      end
    end

    context "when upgrade_legacy_tokens is off" do
      before do
        allow(CommandTower.config.session).to receive(:upgrade_legacy_tokens).and_return(false)
        make_request
      end

      it "leaves the token alone and creates no row" do
        expect(response).to have_http_status(:ok)
        expect(response.headers["X-Authorization-Reset"]).to be_nil
        expect(CommandTower::Auth::DeviceSession.count).to eq(0)
      end
    end
  end

  context "with a device session token" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:session_attrs) { {} }
    let(:device_session) { create(:device_session, user:, **session_attrs) }
    let(:headers) do
      { "Authorization" => "Bearer #{CommandTower::Jwt::LoginCreate.call(user:, device_session:).token}" }
    end

    context "when the session is live" do
      before { make_request }

      it { expect(response).to have_http_status(:ok) }
    end

    context "when the session is revoked" do
      let(:session_attrs) { { revoked_at: 1.minute.ago, revoked_reason: "logout" } }

      before { make_request }

      it "renders session_revoked in the error envelope" do
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["data"]).to be_nil
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("code" => "session_revoked", "message" => "Your session has ended. Please sign in again.")
        )
      end
    end

    context "when the session is idle past the timeout" do
      let(:session_attrs) { { last_seen_at: CommandTower.config.session.idle_timeout.ago - 1.minute } }

      before { make_request }

      it "renders session_expired in the error envelope" do
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["data"]).to be_nil
        expect(response.parsed_body["errors"]).to contain_exactly(
          a_hash_including("code" => "session_expired", "message" => "Your session has expired. Please sign in again.")
        )
      end
    end

    context "when refreshing with X-Authorization-Reset" do
      let(:session_attrs) { { last_seen_at: 1.hour.ago } }
      let(:headers) { super().merge("X-Authorization-Reset" => "true") }

      before { make_request }

      let(:reset_payload) do
        CommandTower::Jwt::Decode.call(token: response.headers["X-Authorization-Reset"]).payload
      end

      it "re-mints a token that keeps the sid and reports the row-derived expiry" do
        expect(reset_payload[:sid]).to eq(device_session.public_id)
        expect(Time.zone.parse(response.headers[expire_header]))
          .to be_within(5.seconds).of(device_session.reload.last_seen_at + CommandTower.config.session.idle_timeout)
      end
    end

    context "when refreshing over cookie" do
      let(:cookie_name) { CommandTower.config.jwt.cookie.name }
      let(:set_cookie) { Array(response.headers["Set-Cookie"]).join("\n")[/#{Regexp.escape(cookie_name)}=[^\n]*/i] }
      let(:expires) { Time.zone.parse(set_cookie[/expires=([^;]+)/i, 1]) }

      before do
        CommandTower.configure { |config| config.jwt.cookie.enabled = true }
        cookies[cookie_name] = CommandTower::Jwt::LoginCreate.call(user:, device_session:).token
        get path, headers: { "X-Authorization-Reset" => "true" }
      end

      after do
        CommandTower.configure { |config| config.jwt.cookie.enabled = false }
      end

      it "rotates the cookie without the token header" do
        expect(response).to have_http_status(:ok)
        expect(response.headers["X-Authorization-Reset"]).to be_nil
        expect(Array(response.headers["Set-Cookie"]).join).to include("#{cookie_name}=")
      end

      it "expires the cookie at the session's absolute expiry" do
        expect(expires).to be_within(5.seconds).of(device_session.reload.absolute_expires_at)
      end
    end

    context "when counting queries against a legacy token" do
      let(:session_attrs) { { last_seen_at: 1.hour.ago } }

      let(:count_queries) do
        lambda do |&request|
          count = 0
          counter = lambda do |*, payload|
            count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
          end
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &request)
          count
        end
      end
      let(:legacy_headers) { { "Authorization" => "Bearer #{CommandTower::Jwt::LoginCreate.call(user:).token}" } }
      let(:legacy_query_count) { count_queries.call { get path, headers: legacy_headers } }
      let(:session_query_count) { count_queries.call { get path, headers: headers } }

      before do
        headers
        get path, headers: legacy_headers # warm caches
        legacy_query_count
        session_query_count
      end

      it "costs at most the session lookup plus the throttled last_seen write" do
        expect(session_query_count).to be <= legacy_query_count + 2
      end
    end

    context "when the kill switch is off" do
      let(:session_attrs) { { revoked_at: 1.minute.ago, revoked_reason: "logout" } }

      before do
        CommandTower.configure { |config| config.session.enforce = false }
        make_request
      end

      after do
        CommandTower.configure { |config| config.session.enforce = true }
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context "when the verifier was rotated" do
      let(:legacy_token) { CommandTower::Jwt::LoginCreate.call(user:).token }
      let(:legacy_body) do
        get path, headers: { "Authorization" => "Bearer #{legacy_token}" }
        response.body
      end

      before do
        legacy_token
        headers
        user.reset_verifier_token!
        legacy_body
        get path, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }
      it { expect(response.body).to eq(legacy_body) }
      it { expect(response_error_code).to eq("unauthorized") }
    end

    context "when revoked over cookie" do
      let(:session_attrs) { { revoked_at: 1.minute.ago, revoked_reason: "logout" } }
      let(:cookie_name) { CommandTower.config.jwt.cookie.name }

      before do
        CommandTower.configure { |config| config.jwt.cookie.enabled = true }
        cookies[cookie_name] = CommandTower::Jwt::LoginCreate.call(user:, device_session:).token
        get path
      end

      after do
        CommandTower.configure { |config| config.jwt.cookie.enabled = false }
      end

      it "clears the JWT cookie as on today's 401" do
        expect(response).to have_http_status(:unauthorized)
        expect(Array(response.headers["Set-Cookie"]).join).to match(/#{Regexp.escape(cookie_name)}=;/)
      end
    end
  end

  context "with an unverified email over cookie" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"], created_at: 5.minutes.ago) }
    let(:cookie_name) { CommandTower.config.jwt.cookie.name }

    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = true
        config.login.plain_text.email_verify.enable = true
      end
      cookies[cookie_name] = login_token_for(user)
      make_request
    end

    after do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = false
      end
    end

    let(:set_cookie) { Array(response.headers["Set-Cookie"]).join }

    it { expect(response).to have_http_status(:precondition_failed) }

    it "does not expire the JWT cookie" do
      expect(set_cookie).not_to match(/#{Regexp.escape(cookie_name)}=;/)
    end
  end
end
