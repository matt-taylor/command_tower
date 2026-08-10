# frozen_string_literal: true

# Integration: cookie login/logout lifecycle and cookie-disabled matrix.
# CSRF enforcement/rotation lives in cookie_csrf_spec.rb.
# Cookie fallback/invalidation lives in cookie_authentication_fallback_spec.rb.

RSpec.describe "Cookie session lifecycle", type: :controller do
  let(:fake_user) { create(:user, :role_admin, password:) }
  let(:password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:cookie_name) { "ct_jwt" }
  let(:response_body) { JSON.parse(response.body) }

  describe "when cookie auth is enabled" do
    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = true
      end
    end

    describe CommandTower::Auth::PlainText::LoginController do
      routes { CommandTower::Engine.routes }

      describe "POST /auth/plain-text/login" do
        subject(:login_post) { post(:create, params: login_params) }

        let(:login_params) { { identifier: fake_user.username, password: } }
        let(:set_cookie_header) { response.headers["Set-Cookie"] }
        let(:reset_header) { response.headers["X-Authorization-Reset"] }
        let(:expire_header) { response.headers["X-Authorization-Expire"] }

        it "sets cookie when login is successful" do
          login_post

          expect(response.status).to eq(201)
          expect(set_cookie_header).to be_present
          # Handle both string and array
          cookie_headers = set_cookie_header.is_a?(Array) ? set_cookie_header.join(" ") : set_cookie_header
          expect(cookie_headers).to include(cookie_name)
          # Find the JWT cookie specifically
          jwt_cookie = set_cookie_header.is_a?(Array) ? set_cookie_header.find { |h| h.include?("#{cookie_name}=") } : set_cookie_header
          expect(jwt_cookie).to match(/httponly/i) if jwt_cookie
          expect(cookie_headers).to match(/samesite=lax/i)
          expect(cookie_headers).to include(response_body.dig("data", "token"))
        end

        it "sets X-Authorization-Reset header with token" do
          login_post

          expect(response.status).to eq(201)
          expect(reset_header).to eq(response_body.dig("data", "token"))
        end

        it "sets X-Authorization-Expire header" do
          login_post

          expect(response.status).to eq(201)
          expect(expire_header).to be_present
          expect(Time.parse(expire_header)).to be_within(1.second).of(CommandTower.config.jwt.ttl.from_now)
        end
      end
    end

    describe CommandTower::Auth::LogoutController do
      routes { CommandTower::Engine.routes }

      describe "POST /auth/logout" do
        subject(:logout_post) { post(:create) }

        let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:cookie_value) { login_data[:cookie_value] }
        let(:clear_cookie_header) { response.headers["Set-Cookie"] }

        context "when cookie is set" do
          before do
            @request.cookies[cookie_name] = cookie_value
            unset_jwt_token!
          end

          it "clears JWT cookie when logout is called" do
            logout_post

            expect(response.status).to eq(200)
            expect(clear_cookie_header).to be_present
            # Handle both string and array (when CSRF cookie is also cleared)
            cookie_headers = clear_cookie_header.is_a?(Array) ? clear_cookie_header.join(" ") : clear_cookie_header
            expect(cookie_headers).to include("#{cookie_name}=")
            expect(cookie_headers).to match(/expires=[^;]+/i)
          end
        end

        context "when both JWT cookie and CSRF cookie are set" do
          let(:csrf_token) { CommandTower::Jwt::CsrfHelper.generate_token }

          before do
            CommandTower.configure do |config|
              config.jwt.cookie.enabled = true
              config.jwt.cookie.csrf.enabled = true
            end
            @request.cookies[cookie_name] = cookie_value
            set_csrf_cookie!(csrf_token)
            unset_jwt_token!
          end

          it "clears both JWT cookie and CSRF cookie" do
            logout_post

            expect(response.status).to eq(200)
            expect(clear_cookie_header).to be_present
            # Handle both string and array
            cookie_headers = clear_cookie_header.is_a?(Array) ? clear_cookie_header : [clear_cookie_header]

            # Verify JWT cookie is cleared
            jwt_cookie = cookie_headers.find { |h| h.include?("#{cookie_name}=") }
            expect(jwt_cookie).to be_present
            expect(jwt_cookie).to match(/expires=[^;]+/i)

            # Verify CSRF cookie is cleared
            csrf_cookie = cookie_headers.find { |h| h.include?("ct_csrf=") }
            expect(csrf_cookie).to be_present
            expect(csrf_cookie).to match(/max-age=0/i)
          end
        end

        it "returns success message" do
          logout_post

          expect(response.status).to eq(200)
          expect(response_body.dig("data", "message")).to eq("logged_out")
        end
      end
    end
  end

  describe "when cookie auth is disabled" do
    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = false
      end
    end

    describe CommandTower::Auth::PlainText::LoginController do
      routes { CommandTower::Engine.routes }

      describe "POST /auth/plain-text/login" do
        subject(:login_post) { post(:create, params: { identifier: fake_user.username, password: }) }

        let(:set_cookie_header) { response.headers["Set-Cookie"] }

        it "does not set cookie on login" do
          login_post

          expect(response.status).to eq(201)
          expect(set_cookie_header).to be_nil
        end
      end
    end

    describe CommandTower::ProtectedFixtureController, :protected_fixture do
      describe "Cookie fallback authentication" do
        subject(:show_user) { get(:show) }

        let(:token) { CommandTower::Jwt::LoginCreate.(user: fake_user).token }

        before do
          @request.cookies[cookie_name] = token
          unset_jwt_token!
        end

        it "does not use cookie for authentication fallback" do
          show_user

          expect(response.status).to eq(401)
        end
      end

      describe "Token refresh" do
        subject(:show_user_with_reset) do
          set_jwt_token!(user: fake_user, token:, with_reset: true)
          get(:show)
        end

        let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:token) { login_data[:token] }
        let(:set_cookie_header) { response.headers["Set-Cookie"] }

        it "does not update cookie on token refresh" do
          show_user_with_reset

          expect(set_cookie_header).to be_nil
        end
      end
    end

    describe CommandTower::Auth::LogoutController do
      routes { CommandTower::Engine.routes }

      describe "POST /auth/logout" do
        subject(:logout_post) { post(:create) }

        it "logout still works (no-op when cookies disabled)" do
          logout_post

          expect(response.status).to eq(200)
          expect(response_body.dig("data", "message")).to eq("logged_out")
        end
      end
    end
  end
end
