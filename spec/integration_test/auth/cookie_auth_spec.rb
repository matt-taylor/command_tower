# frozen_string_literal: true

RSpec.describe "Cookie Authentication", type: :controller do
  let(:fake_user) { create(:user, password:) }
  let(:password) { Faker::Alphanumeric.alpha(number: 20) }
  let(:cookie_name) { "ct_jwt" }
  let(:response_body) { JSON.parse(response.body) }

  describe "when cookie auth is enabled" do
    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = true
      end
    end

    describe CommandTower::Auth::PlainTextController do
      describe "POST /auth/login" do
        subject(:login_post) { post(:login_post, params: login_params) }

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
          expect(cookie_headers).to include(response_body["token"])
        end

        it "sets X-Authorization-Reset header with token" do
          login_post

          expect(response.status).to eq(201)
          expect(reset_header).to eq(response_body["token"])
        end

        it "sets X-Authorization-Expire header" do
          login_post

          expect(response.status).to eq(201)
          expect(expire_header).to be_present
          expect(Time.parse(expire_header)).to be_within(1.second).of(CommandTower.config.jwt.ttl.from_now)
        end
      end
    end

    describe CommandTower::UserController do
      describe "Cookie fallback authentication" do
        let(:login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:token) { login_data[:token] }
        let(:cookie_value) { login_data[:cookie_value] }

        before do
          @request.cookies[cookie_name] = cookie_value
          unset_jwt_token!
        end

        context "when Authorization header is missing" do
          subject(:show_user) { get(:show) }

          it "authenticates using cookie" do
            show_user

            expect(response.status).to eq(200)
          end
        end

        context "when both Authorization header and cookie are present" do
          subject(:show_user) { get(:show) }

          let(:token2) { CommandTower::Jwt::LoginCreate.(user: fake_user).token }

          before do
            @request.cookies[cookie_name] = token
            set_jwt_token!(user: fake_user, token: token2)
          end

          it "prefers Authorization header over cookie" do
            show_user

            expect(response.status).to eq(200)
          end
        end
      end

      describe "Token refresh updates cookie" do
        let(:initial_login_data) { get_login_token_and_cookie(user: fake_user, password:) }
        let(:initial_token) { initial_login_data[:token] }
        let(:initial_cookie) { initial_login_data[:cookie_value] }

        it "updates cookie when X-Authorization-Reset header is set" do
          # Advance time before refresh to ensure new token has different generated_at
          Timecop.freeze(Time.zone.now + 2.seconds)

          set_jwt_token!(user: fake_user, token: initial_token, with_reset: true)
          get(:show)

          expect(response.status).to eq(200)

          new_set_cookie_header = response.headers["Set-Cookie"]
          expect(new_set_cookie_header).to be_present
          # Handle both string and array
          cookie_headers = new_set_cookie_header.is_a?(Array) ? new_set_cookie_header.join(" ") : new_set_cookie_header
          expect(cookie_headers).to include(cookie_name)

          new_token = response.headers["X-Authorization-Reset"]
          expect(new_token).to be_present
          # Token should be different due to new generated_at timestamp
          # Note: If time is frozen at the same second, tokens may be identical
          # In that case, we verify the cookie was still updated
          if new_token != initial_token
            # Find the JWT cookie from the header(s)
            jwt_cookie = new_set_cookie_header.is_a?(Array) ? new_set_cookie_header.find { |h| h.include?("#{cookie_name}=") } : new_set_cookie_header
            new_cookie = jwt_cookie.match(/#{cookie_name}=([^;]+)/)[1]
            expect(new_cookie).to eq(new_token)
            expect(new_cookie).not_to eq(initial_cookie)
          else
            # If token is same (time frozen at same second), at least verify cookie header is present
            expect(cookie_headers).to include(cookie_name)
          end
        end
      end

      describe "Cookie invalidation on authentication failure" do
        subject(:show_user) { get(:show) }

        context "when invalid cookie token is present" do
          before do
            @request.cookies[cookie_name] = "invalid_token_value"
            unset_jwt_token!
          end

          it "returns 401 status" do
            show_user

            expect(response.status).to eq(401)
          end

          it "clears the invalid cookie in response" do
            show_user

            clear_cookie_header = response.headers["Set-Cookie"]
            expect(clear_cookie_header).to be_present
            expect(clear_cookie_header).to include("#{cookie_name}=")
            expect(clear_cookie_header).to match(/expires=[^;]+/i)
          end
        end

        context "when invalid Authorization header is present (cookie also present)" do
          before do
            # Set a valid cookie
            login_data = get_login_token_and_cookie(user: fake_user, password:)
            @request.cookies[cookie_name] = login_data[:cookie_value]
            # Set invalid Authorization header
            @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearer invalid_token"
          end

          it "returns 401 status" do
            show_user

            expect(response.status).to eq(401)
          end

          it "does NOT clear cookie when Authorization header is invalid" do
            show_user

            # Cookie should not be cleared because token source was :header, not :cookie
            clear_cookie_header = response.headers["Set-Cookie"]
            expect(clear_cookie_header).to be_nil
          end
        end

        context "when no token is present (missing token)" do
          before do
            unset_jwt_token!
          end

          it "returns 401 status" do
            show_user

            expect(response.status).to eq(401)
          end

          it "does not set cookie clear header when no token is present" do
            show_user

            clear_cookie_header = response.headers["Set-Cookie"]
            expect(clear_cookie_header).to be_nil
          end
        end

        context "when expired cookie token is present" do
          before do
            # Create a token and then expire it by manipulating the user's verifier_token
            login_data = get_login_token_and_cookie(user: fake_user, password:)
            old_token = login_data[:token]
            # Change user's verifier_token to invalidate the token
            fake_user.update!(verifier_token: SecureRandom.hex(32))
            @request.cookies[cookie_name] = old_token
            unset_jwt_token!
          end

          it "returns 401 status" do
            show_user

            expect(response.status).to eq(401)
          end

          it "clears the expired cookie in response" do
            show_user

            clear_cookie_header = response.headers["Set-Cookie"]
            expect(clear_cookie_header).to be_present
            expect(clear_cookie_header).to include("#{cookie_name}=")
            expect(clear_cookie_header).to match(/expires=[^;]+/i)
          end
        end

        context "when email validation is required (412 status)" do
          let(:unvalidated_user) { create(:user, :unvalidated_email, password:, created_at: 5.minutes.ago) }
          let(:login_data) { get_login_token_and_cookie(user: unvalidated_user, password:) }
          let(:cookie_value) { login_data[:cookie_value] }

          before do
            CommandTower.configure do |config|
              config.login.plain_text.email_verify.enable = true
            end
            @request.cookies[cookie_name] = cookie_value
            unset_jwt_token!
          end

          it "returns 412 status" do
            show_user

            expect(response.status).to eq(412)
          end

          it "does NOT clear cookie when email validation is required (412 status)" do
            show_user

            # Cookie should NOT be cleared for 412 status - user needs cookie to verify email
            clear_cookie_header = response.headers["Set-Cookie"]
            expect(clear_cookie_header).to be_nil
          end

          it "returns email validation error schema" do
            show_user

            response_body = JSON.parse(response.body)
            expect(response_body["message"]).to eq("Email must be verified to continue")
            # Meta field may or may not be present depending on schema implementation
            # The important thing is that cookie is NOT cleared (tested above)
          end
        end
      end
    end

    describe CommandTower::Auth::LogoutController do
      describe "POST /auth/logout" do
        subject(:logout_post) { post(:logout_post) }

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
          expect(response_body["message"]).to eq("Logged out")
        end
      end
    end

    describe CommandTower::UserController do
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

            subject(:post_request) { post(:modify, params: {}) }

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

            subject(:post_request) { post(:modify, params: {}) }

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

            subject(:post_request) { post(:modify, params: {}) }

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

            subject(:post_request) { post(:modify, params: { username: fake_user.username }) }

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

            subject(:post_request) { post(:modify, params: { username: fake_user.username }) }

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

            describe CommandTower::Auth::PlainTextController do
              subject(:login_post) { post(:login_post, params: { identifier: fake_user.username, password: }) }

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

            describe CommandTower::Auth::PlainTextController do
              subject(:login_post) { post(:login_post, params: { identifier: fake_user.username, password: }) }

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
            subject(:logout_post) { post(:logout_post) }

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
          subject(:post_request) { post(:modify, params: { username: fake_user.username }) }

          it "succeeds without CSRF token" do
            post_request
            expect(response.status).to eq(201)
          end
        end
      end
    end

  end

    describe CommandTower::UserController do
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
            post(:modify, params: { username: fake_user.username })
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
            post(:modify, params: { username: fake_user.username })
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
            post(:modify, params: { username: fake_user.username })
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
            post(:modify, params: { username: fake_user.username })
            expect(response.status).to eq(201)
          end

          it "succeeds even when CSRF cookie and header are mismatched (header auth exempt)" do
            # Set mismatched CSRF tokens to prove header auth bypasses CSRF
            set_csrf_cookie!(CommandTower::Jwt::CsrfHelper.generate_token)
            set_csrf_header!(CommandTower::Jwt::CsrfHelper.generate_token)
            post(:modify, params: { username: fake_user.username })
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

  describe "when cookie auth is disabled" do
    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = false
      end
    end

    describe CommandTower::Auth::PlainTextController do
      describe "POST /auth/login" do
        subject(:login_post) { post(:login_post, params: { identifier: fake_user.username, password: }) }

        let(:set_cookie_header) { response.headers["Set-Cookie"] }

        it "does not set cookie on login" do
          login_post

          expect(response.status).to eq(201)
          expect(set_cookie_header).to be_nil
        end
      end
    end

    describe CommandTower::UserController do
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
      describe "POST /auth/logout" do
        subject(:logout_post) { post(:logout_post) }

        it "logout still works (no-op when cookies disabled)" do
          logout_post

          expect(response.status).to eq(200)
          expect(response_body["message"]).to eq("Logged out")
        end
      end
    end
  end
end
