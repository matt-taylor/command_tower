# frozen_string_literal: true

# Integration: CSRF enforcement, issuance/rotation, and header-auth precedence.

RSpec.describe "Cookie CSRF protection", type: :controller do
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

    describe CommandTower::ProtectedFixtureController, :protected_fixture do
      describe "CSRF protection for cookie-authenticated requests" do
        let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:cookie_value) { login_data[:cookie_value] }
        let(:csrf_cookie_name) { CommandTower.config.jwt.cookie.csrf.cookie_name }
        let(:csrf_header_name) { CommandTower.config.jwt.cookie.csrf.header_name }

        before do
          CommandTower.configure do |config|
            config.jwt.cookie.enabled = true
            config.jwt.cookie.csrf.enabled = true
          end
          @request.cookies[cookie_name] = cookie_value
          unset_jwt_token!
        end

        context "when CSRF is required (cookie-auth unsafe method)" do
          let(:csrf_token) { CommandTower::Jwt::CsrfHelper.generate_token }

          context "with missing CSRF header" do
            before do
              set_csrf_cookie!(csrf_token)
            end

            subject(:post_request) { post(:modify, params: { user_id: fake_user.id }) }

            it "returns 403 status" do
              post_request
              expect(response.status).to eq(403)
            end

            it "returns csrf_missing error message" do
              post_request
              expect(JSON.parse(response.body)["message"]).to eq("csrf_missing")
            end
          end

          context "with missing CSRF cookie" do
            before do
              set_csrf_header!(csrf_token)
            end

            subject(:post_request) { post(:modify, params: { user_id: fake_user.id }) }

            it "returns 403 status" do
              post_request
              expect(response.status).to eq(403)
            end

            it "returns csrf_missing error message" do
              post_request
              expect(JSON.parse(response.body)["message"]).to eq("csrf_missing")
            end
          end

          context "with mismatched CSRF tokens" do
            let(:cookie_token) { CommandTower::Jwt::CsrfHelper.generate_token }
            let(:header_token) { CommandTower::Jwt::CsrfHelper.generate_token }

            before do
              set_csrf_cookie!(cookie_token)
              set_csrf_header!(header_token)
            end

            subject(:post_request) { post(:modify, params: { user_id: fake_user.id }) }

            it "returns 403 status" do
              post_request
              expect(response.status).to eq(403)
            end

            it "returns csrf_mismatch error message" do
              post_request
              expect(JSON.parse(response.body)["message"]).to eq("csrf_mismatch")
            end
          end

          context "with matching CSRF tokens" do
            let(:csrf_token) { CommandTower::Jwt::CsrfHelper.generate_token }

            before do
              set_csrf_cookie!(csrf_token)
              set_csrf_header!(csrf_token)
            end

            subject(:post_request) { post(:modify, params: { user_id: fake_user.id, username: fake_user.username }) }

            it "succeeds" do
              post_request
              expect(response.status).to eq(201)
            end
          end
        end

        context "when CSRF is not required" do
          context "with Authorization header (header-auth)" do
            let(:token) { CommandTower::Jwt::LoginCreate.(user: fake_user).token }

            before do
              set_jwt_token!(user: fake_user, token:)
              @request.cookies.delete(cookie_name)
            end

            subject(:post_request) { post(:modify, params: { user_id: fake_user.id, username: fake_user.username }) }

            it "succeeds without CSRF token" do
              post_request
              expect(response.status).to eq(201)
            end
          end

          context "with GET request" do
            subject(:get_request) { get(:show) }

            it "succeeds without CSRF token" do
              get_request
              expect(response.status).to eq(200)
            end
          end
        end
      end

      describe "CSRF cookie issuance and rotation" do
        let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:cookie_value) { login_data[:cookie_value] }

        before do
          CommandTower.configure do |config|
            config.jwt.cookie.enabled = true
            config.jwt.cookie.csrf.enabled = true
          end
        end

        context "on login" do
          context "when rotate_on_login is true" do
            before do
              CommandTower.configure do |config|
                config.jwt.cookie.csrf.rotate_on_login = true
              end
            end

            describe CommandTower::Auth::PlainText::LoginController do
              routes { CommandTower::Engine.routes }

              subject(:login_post) { post(:create, params: { identifier: fake_user.username, password: }) }

              it "sets CSRF cookie" do
                login_post
                csrf_cookie = extract_csrf_cookie(response)
                expect(csrf_cookie).to be_present
              end

              it "sets CSRF cookie with non-HttpOnly flag" do
                login_post
                set_cookie_header = response.headers["Set-Cookie"]
                # Handle both string and array
                cookie_headers = set_cookie_header.is_a?(Array) ? set_cookie_header.join(" ") : set_cookie_header
                expect(cookie_headers).to match(/ct_csrf=/)
                # Check that ct_csrf cookie specifically doesn't have httponly
                csrf_cookie = set_cookie_header.is_a?(Array) ? set_cookie_header.find { |h| h.include?("ct_csrf=") } : set_cookie_header
                expect(csrf_cookie).not_to match(/httponly/i) if csrf_cookie
              end
            end
          end

          context "when rotate_on_login is false" do
            before do
              CommandTower.configure do |config|
                config.jwt.cookie.csrf.rotate_on_login = false
              end
            end

            describe CommandTower::Auth::PlainText::LoginController do
              routes { CommandTower::Engine.routes }

              subject(:login_post) { post(:create, params: { identifier: fake_user.username, password: }) }

              it "creates CSRF cookie when missing (rotate_on_login=false means don't force rotation, but ensure exists)" do
                login_post
                csrf_cookie = extract_csrf_cookie(response)
                expect(csrf_cookie).to be_present
              end

              context "when CSRF cookie already exists" do
                let(:existing_csrf_token) { CommandTower::Jwt::CsrfHelper.generate_token }

                before do
                  set_csrf_cookie!(existing_csrf_token)
                end

                it "does not set CSRF cookie in response (no rotation, cookie already exists)" do
                  login_post
                  # When cookie exists and rotate_on_login=false, ensure_cookie does nothing
                  # Expect NO Set-Cookie header for CSRF (cookie exists, not rotated)
                  csrf_cookie = extract_csrf_cookie(response)
                  expect(csrf_cookie).to be_nil
                end

                it "keeps existing CSRF cookie value in request" do
                  login_post
                  # Cookie should still exist in request (not cleared)
                  expect(get_csrf_cookie_value).to eq(existing_csrf_token)
                end
              end

              context "when CSRF cookie does not exist" do
                it "creates CSRF cookie (ensures it exists)" do
                  login_post
                  csrf_cookie = extract_csrf_cookie(response)
                  expect(csrf_cookie).to be_present
                end
              end
            end
          end
        end

        context "on token reset" do
          let(:initial_login_data) { get_login_token_and_cookie(user: fake_user, password:) }
          let(:initial_token) { initial_login_data[:token] }

          before do
            @request.cookies[cookie_name] = initial_login_data[:cookie_value]
            unset_jwt_token!
          end

          context "when rotate_on_reset is true" do
            before do
              CommandTower.configure do |config|
                config.jwt.cookie.csrf.rotate_on_reset = true
              end
              Timecop.freeze(Time.zone.now + 2.seconds)
              set_jwt_token!(user: fake_user, token: initial_token, with_reset: true)
            end

            subject(:get_request) { get(:show) }

            it "rotates CSRF cookie" do
              get_request
              csrf_cookie = extract_csrf_cookie(response)
              expect(csrf_cookie).to be_present
            end
          end
        end

        context "on logout" do
          let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
          let(:csrf_token) { CommandTower::Jwt::CsrfHelper.generate_token }

          before do
            @request.cookies[cookie_name] = login_data[:cookie_value]
            set_csrf_cookie!(csrf_token)
            unset_jwt_token!
          end

          describe CommandTower::Auth::LogoutController do
            routes { CommandTower::Engine.routes }

            subject(:logout_post) { post(:create) }

            it "clears CSRF cookie" do
              logout_post
              clear_cookie_header = response.headers["Set-Cookie"]
              # Handle both string and array
              cookie_headers = clear_cookie_header.is_a?(Array) ? clear_cookie_header.join(" ") : clear_cookie_header
              expect(cookie_headers).to match(/ct_csrf=/)
              expect(cookie_headers).to match(/max-age=0/i)
            end
          end
        end
      end

      describe "CSRF disabled behavior" do
        let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:cookie_value) { login_data[:cookie_value] }

        before do
          CommandTower.configure do |config|
            config.jwt.cookie.enabled = true
            config.jwt.cookie.csrf.enabled = false
          end
          @request.cookies[cookie_name] = cookie_value
          unset_jwt_token!
        end

        context "with cookie-authenticated POST request" do
          subject(:post_request) { post(:modify, params: { user_id: fake_user.id, username: fake_user.username }) }

          it "succeeds without CSRF token" do
            post_request
            expect(response.status).to eq(201)
          end
        end
      end
    end
  end

    describe CommandTower::ProtectedFixtureController, :protected_fixture do
      describe "Header-only authentication (legacy workflow)" do
        let(:token) { CommandTower::Jwt::LoginCreate.(user: fake_user).token }

        before do
          set_jwt_token!(user: fake_user, token:)
          # Explicitly remove cookies to ensure header-only auth
          @request.cookies.delete(cookie_name) if @request.cookies.key?(cookie_name)
        end

        context "when cookies are disabled (legacy mode)" do
          before do
            CommandTower.configure do |config|
              config.jwt.cookie.enabled = false
            end
          end

          it "succeeds with GET request" do
            get(:show)
            expect(response.status).to eq(200)
          end

          it "succeeds with POST request" do
            post(:modify, params: { user_id: fake_user.id, username: fake_user.username })
            expect(response.status).to eq(201)
          end

          it "succeeds with token refresh" do
            set_jwt_token!(user: fake_user, token:, with_reset: true)
            get(:show)
            expect(response.status).to eq(200)
            expect(response.headers["X-Authorization-Reset"]).to be_present
          end
        end

        context "when cookies are enabled but CSRF is disabled" do
          before do
            CommandTower.configure do |config|
              config.jwt.cookie.enabled = true
              config.jwt.cookie.csrf.enabled = false
            end
          end

          it "succeeds with GET request" do
            get(:show)
            expect(response.status).to eq(200)
          end

          it "succeeds with POST request without CSRF token" do
            post(:modify, params: { user_id: fake_user.id, username: fake_user.username })
            expect(response.status).to eq(201)
          end

          it "succeeds with token refresh" do
            set_jwt_token!(user: fake_user, token:, with_reset: true)
            get(:show)
            expect(response.status).to eq(200)
            expect(response.headers["X-Authorization-Reset"]).to be_present
          end
        end

        context "when cookies and CSRF are both enabled" do
          before do
            CommandTower.configure do |config|
              config.jwt.cookie.enabled = true
              config.jwt.cookie.csrf.enabled = true
            end
          end

          it "succeeds with GET request" do
            get(:show)
            expect(response.status).to eq(200)
          end

          it "succeeds with POST request without CSRF token" do
            post(:modify, params: { user_id: fake_user.id, username: fake_user.username })
            expect(response.status).to eq(201)
          end

          it "succeeds with token refresh" do
            set_jwt_token!(user: fake_user, token:, with_reset: true)
            get(:show)
            expect(response.status).to eq(200)
            expect(response.headers["X-Authorization-Reset"]).to be_present
          end
        end

        context "when cookies and CSRF are enabled AND cookie is present (header takes precedence)" do
          let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
          let(:cookie_value) { login_data[:cookie_value] }

          before do
            CommandTower.configure do |config|
              config.jwt.cookie.enabled = true
              config.jwt.cookie.csrf.enabled = true
            end
            # Set cookie in request but header should still take precedence
            @request.cookies[cookie_name] = cookie_value
            # Also set CSRF cookie to ensure header auth bypasses CSRF
            csrf_token = CommandTower::Jwt::CsrfHelper.generate_token
            set_csrf_cookie!(csrf_token)
          end

          it "succeeds with GET request (header takes precedence over cookie)" do
            get(:show)
            expect(response.status).to eq(200)
          end

          it "succeeds with POST request without CSRF token (header auth exempt from CSRF)" do
            post(:modify, params: { user_id: fake_user.id, username: fake_user.username })
            expect(response.status).to eq(201)
          end

          it "succeeds even when CSRF cookie and header are mismatched (header auth exempt)" do
            # Set mismatched CSRF tokens to prove header auth bypasses CSRF
            set_csrf_cookie!(CommandTower::Jwt::CsrfHelper.generate_token)
            set_csrf_header!(CommandTower::Jwt::CsrfHelper.generate_token)
            post(:modify, params: { user_id: fake_user.id, username: fake_user.username })
            expect(response.status).to eq(201)
          end

          it "succeeds with token refresh" do
            set_jwt_token!(user: fake_user, token:, with_reset: true)
            get(:show)
            expect(response.status).to eq(200)
            expect(response.headers["X-Authorization-Reset"]).to be_present
          end
        end
      end
    end
end
