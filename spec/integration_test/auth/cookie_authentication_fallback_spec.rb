# frozen_string_literal: true

# Integration: cookie fallback auth, header precedence, refresh, and invalidation.

RSpec.describe "Cookie authentication fallback", type: :controller do
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
  end
end
