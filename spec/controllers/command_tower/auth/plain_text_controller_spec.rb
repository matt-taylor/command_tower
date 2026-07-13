# frozen_string_literal: true

RSpec.describe CommandTower::Auth::PlainTextController, type: :controller do
  let(:response_body) { JSON.parse(response.body) }

  describe "POST: create_post" do
    subject(:create_post) { post(:create_post, params:) }

    let(:params) do
      {
        first_name:,
        last_name:,
        username:,
        email:,
        password:,
        password_confirmation:,
      }.compact
    end
    let(:first_name) { Faker::Name.first_name }
    let(:last_name) { Faker::Name.last_name }
    let(:username) { "d" + Faker::Lorem.characters(number: CommandTower.config.username.username_length_max - 1) }
    let(:email) { Faker::Internet.email }
    let(:password) { Faker::Alphanumeric.alpha(number: 20) }
    let(:password_confirmation) { password }

    context "with invalid email" do
      let(:email) { "Invalid$emailaddy" }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Invalid email address", :email
    end

    context "with invalid username" do
      let(:username) { " this i!s my username " }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Username is invalid", :username
    end

    context "with invalid password" do
      let(:password_confirmation) { "does not equal" }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "doesn't match Password", :password_confirmation
    end

    context "with missing parameters" do
      context "multiple missing" do
        let(:first_name) { nil }
        let(:last_name) { nil }
        let(:password) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, ["[first_name]", "[first_name]", "[password]"], [:first_name, :first_name, :password]
      end

      context "with first_name" do
        let(:first_name) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Parameter [first_name]", :first_name
      end

      context "with last_name" do
        let(:last_name) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Parameter [last_name]", :last_name
      end

      context "with username" do
        let(:username) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Parameter [username]", :username
      end

      context "with email" do
        let(:email) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Parameter [email]", :email
      end

      context "with password" do
        let(:password) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Parameter [password]", :password
      end

      context "with password_confirmation" do
        let(:password_confirmation) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Parameter [password_confirmation]", :password_confirmation
      end
    end

    it "returns 201" do
      create_post

      expect(response.status).to eq(201)
    end

    it "creates user" do
      expect { create_post }.to change(User, :count).by(1)
    end

    it "returns user data" do
      create_post

      # we know from the above test, only one user is created per test...can infer the last user was the one created
      user = User.last
      expect(response_body).to include(
        {
          "full_name" => user.full_name,
          "first_name" => user.first_name,
          "last_name" => user.last_name,
          "username" => user.username,
          "email" => anything, # email is filtered and does not do RSpec matchers well
          "msg" => "Successfully created new User",
        }
      )
    end
  end

  describe "POST: email_verify_post" do
    subject(:email_verify_post) { post(:email_verify_post, params:) }

    let(:code) do
      result = CommandTower::LoginStrategy::PlainText::EmailVerification::Generate.(user:)
      result.secret
    end
    let(:params) { { code: }.compact }
    let(:user) { create(:user, :unvalidated_email) }

    include_examples "Invalid/Missing JWT token on required route"

    context "with invalid code" do
      before { set_jwt_token!(user:) }
      let(:code) { "this is an incorrect code" }
      let(:user) { create(:user, :unvalidated_email) }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 403, "Incorrect verification code provided", :code

      context "with mismatched code and user" do
        let(:incorrect_user) { create(:user, :unvalidated_email) }
        let(:code) do
          result = CommandTower::LoginStrategy::PlainText::EmailVerification::Generate.(user: incorrect_user)
          result.secret
        end

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 403, "Incorrect verification code provided", :code
      end
    end

    context "with unvalidated_email" do
      before { set_jwt_token!(user:) }

      it "returns success" do
        subject
        expect(response.status).to eq(201)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Successfully verified email")
      end
    end

    context "with validated email" do
      before { set_jwt_token!(user:) }
      let(:user) { create(:user) }

      it "returns success" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Email is already verified.")
      end
    end
  end

  describe "POST: email_verify_resend_post" do
    subject(:email_verify_resend_post) { post(:email_verify_resend_post) }

    before { set_jwt_token!(user:) }
    let(:user) { create(:user, :unvalidated_email) }
    include_examples "Invalid/Missing JWT token on required route"

    it "returns success" do
      subject
      expect(response.status).to eq(201)
    end

    it "sets message" do
      subject
      expect(response_body["message"]).to eq("Successfully sent Email verification code")
    end

    context "with email failure" do
      before do
        set_jwt_token!(user:)
        allow(CommandTower::EmailVerificationMailer).to receive(:verify_email).and_raise(StandardError)
      end

      it "returns failure" do
        subject
        expect(response.status).to eq(500)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Unable to send email. Please try again later")
      end
    end

    context "with validated user" do
      let(:user) { create(:user) }

      it "returns success" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Email is already verified. No code required")
      end
    end
  end

  describe "POST: login_post" do
    subject(:login_post) { post(:login_post, params:) }

    let(:params) do
      {
        identifier:,
        password: password_input,
      }.compact
    end
    let(:user) { create(:user, password:) }
    let(:password) { Faker::Alphanumeric.alpha(number: 20) }
    let(:password_input) { password }
    let(:identifier) { nil }

    context "with correct login" do
      context "when identifier is email" do
        let(:identifier) { user.email }

        it "returns success" do
          subject
          expect(response.status).to eq(201)
        end

        it "sets correct body" do
          subject
          expect(response_body["message"]).to eq("Successfully logged user in")
          expect(response_body["token"]).to be_present
          expect(response_body["header_name"]).to eq(CommandTower::ApplicationController::AUTHENTICATION_HEADER)
        end

        it "does not return verifier_token in user object" do
          subject
          expect(response_body["user"]).to_not have_key("verifier_token")
        end
      end

      context "when identifier is username" do
        let(:identifier) { user.username }

        it "returns success" do
          subject
          expect(response.status).to eq(201)
        end

        it "sets correct body" do
          subject
          expect(response_body["message"]).to eq("Successfully logged user in")
          expect(response_body["token"]).to be_present
          expect(response_body["header_name"]).to eq(CommandTower::ApplicationController::AUTHENTICATION_HEADER)
        end

        it "does not return verifier_token in user object" do
          subject
          expect(response_body["user"]).to_not have_key("verifier_token")
        end
      end
    end

    context "with incorrect arguments" do
      context "with missing identifier" do
        let(:identifier) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 401, "Parameter [identifier] is required but not present", [:identifier]
      end

      context "with missing password" do
        let(:identifier) { user.username }
        let(:password_input) { nil }

        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 401, "Parameter [password] is required but not present", [:password]
      end
    end

    context "when failed login" do
      context "with incorrect identifier" do
        let(:identifier) { "not a valid identifier" }
        include_examples "CommandTower::Schema::Error:InvalidArguments examples", 401, "Unauthorized Access. Incorrect Credentials", [:identifier, :password]
      end
    end
  end

  describe "POST: password_forgot_send_post" do
    subject(:password_forgot_send_post) { post(:password_forgot_send_post, params:) }

    let(:params) { { email: }.compact }
    let(:email) { Faker::Internet.email }
    let(:user) { create(:user, email: email) }

    context "with existing user" do
      before { user }

      it "returns 200" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("If an account exists with that email, a password reset link has been sent.")
      end

      it "sends email" do
        expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "with non-existent user" do
      let(:email) { "nonexistent@example.com" }

      it "returns 200" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("If an account exists with that email, a password reset link has been sent.")
      end

      it "does not send email" do
        expect { subject }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "with invalid email" do
      let(:email) { "not-an-email" }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Invalid email address", :email
    end

    context "with missing email" do
      let(:email) { nil }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, /Parameter \[email\]/, [:email]
    end

    context "with email delivery failure" do
      before do
        user
        allow_any_instance_of(CommandTower::PasswordResetMailer).to receive(:reset_password).and_raise(StandardError)
      end

      it "still returns 200" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("If an account exists with that email, a password reset link has been sent.")
      end
    end
  end

  describe "POST: password_forgot_validate_post" do
    subject(:password_forgot_validate_post) { post(:password_forgot_validate_post, params:) }

    let(:user) { create(:user) }
    let(:token) do
      result = CommandTower::Secrets::Generate.(
        user: user,
        secret_length: 32,
        reason: CommandTower::Secrets::PASSWORD_RESET,
        use_count_max: 1,
        death_time: 1.hour,
        type: CommandTower::Secrets::ALPHANUMERIC,
        cleanse: false
      )
      result.secret
    end
    let(:email) { nil }
    let(:params) { { token: token, email: email }.compact }

    context "with valid token" do
      it "returns 200" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets valid to true" do
        subject
        expect(response_body["valid"]).to eq(true)
      end

      it "sets expires_at" do
        subject
        expect(response_body["expires_at"]).to be_present
      end
    end

    context "with require_email: false (backward compatibility)" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
      end

      context "when email is not provided" do
        let(:email) { nil }

        it "returns 200" do
          subject
          expect(response.status).to eq(200)
        end

        it "sets valid to true" do
          subject
          expect(response_body["valid"]).to eq(true)
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "returns 200" do
          subject
          expect(response.status).to eq(200)
        end

        it "sets valid to true" do
          subject
          expect(response_body["valid"]).to eq(true)
        end
      end

      context "when email is provided but does not match" do
        let(:email) { "wrong@example.com" }

        it "returns 401" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Invalid token")
        end
      end
    end

    context "with require_email: true" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(true)
      end

      context "when email is not provided" do
        let(:email) { nil }

        it "returns 400" do
          subject
          expect(response.status).to eq(400)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Email is required")
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "returns 200" do
          subject
          expect(response.status).to eq(200)
        end

        it "sets valid to true" do
          subject
          expect(response_body["valid"]).to eq(true)
        end
      end

      context "when email is provided but does not match" do
        let(:email) { "wrong@example.com" }

        it "returns 401" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Invalid token")
        end
      end
    end

    context "with invalid token" do
      let(:token) { "invalid_token_12345" }

      it "returns 401" do
        subject
        expect(response.status).to eq(401)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Invalid token")
      end
    end

    context "with expired token" do
      let(:token) do
        result = CommandTower::Secrets::Generate.(
          user: user,
          secret_length: 32,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          use_count_max: 1,
          death_time: 1.hour,
          type: CommandTower::Secrets::ALPHANUMERIC,
          cleanse: false
        )
        secret = result.secret
        # Manually expire the token by setting death_time in the past
        user_secret = UserSecret.find_by(secret: secret)
        user_secret.update!(death_time: 1.hour.ago)
        secret
      end

      it "returns 401" do
        subject
        expect(response.status).to eq(401)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Invalid token")
      end
    end

    context "with missing token" do
      let(:token) { nil }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, /Parameter \[token\]/, [:token]
    end
  end

  describe "POST: password_forgot_reset_post" do
    subject(:password_forgot_reset_post) { post(:password_forgot_reset_post, params:) }

    let(:user) { create(:user, password: "old_password123") }
    let(:token) do
      result = CommandTower::Secrets::Generate.(
        user: user,
        secret_length: 32,
        reason: CommandTower::Secrets::PASSWORD_RESET,
        use_count_max: 1,
        death_time: 1.hour,
        type: CommandTower::Secrets::ALPHANUMERIC,
        cleanse: false
      )
      result.secret
    end
    let(:password) { "new_password123" }
    let(:password_confirmation) { password }
    let(:email) { nil }
    let(:params) do
      {
        token:,
        email:,
        password:,
        password_confirmation:,
      }.compact
    end

    context "with valid token and matching passwords" do
      it "returns 200" do
        subject
        expect(response.status).to eq(200)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Password has been successfully reset")
      end

      it "updates user password" do
        subject
        expect(user.reload.authenticate(password)).to be_truthy
      end
    end

    context "with password mismatch" do
      let(:password_confirmation) { "different_password" }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Password and confirmation do not match", :password_confirmation
    end

    context "with invalid token" do
      let(:token) { "invalid_token_12345" }

      it "returns 401" do
        subject
        expect(response.status).to eq(401)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Invalid token")
      end
    end

    context "with expired token" do
      let(:token) do
        result = CommandTower::Secrets::Generate.(
          user: user,
          secret_length: 32,
          reason: CommandTower::Secrets::PASSWORD_RESET,
          use_count_max: 1,
          death_time: 1.hour,
          type: CommandTower::Secrets::ALPHANUMERIC,
          cleanse: false
        )
        secret = result.secret
        # Manually expire the token by setting death_time in the past
        user_secret = UserSecret.find_by(secret: secret)
        user_secret.update!(death_time: 1.hour.ago)
        secret
      end

      it "returns 401" do
        subject
        expect(response.status).to eq(401)
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Invalid token")
      end
    end

    context "with missing token" do
      let(:token) { nil }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, /Parameter \[token\]/, [:token]
    end

    context "with missing password" do
      let(:password) { nil }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, /Parameter \[password\]/, [:password]
    end

    context "with require_email: false (backward compatibility)" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(false)
      end

      context "when email is not provided" do
        let(:email) { nil }

        it "returns 200" do
          subject
          expect(response.status).to eq(200)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Password has been successfully reset")
        end

        it "updates user password" do
          subject
          expect(user.reload.authenticate(password)).to be_truthy
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "returns 200" do
          subject
          expect(response.status).to eq(200)
        end

        it "updates user password" do
          subject
          expect(user.reload.authenticate(password)).to be_truthy
        end
      end

      context "when email is provided but does not match" do
        let(:email) { "wrong@example.com" }

        it "returns 401" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Invalid token")
        end
      end
    end

    context "with require_email: true" do
      before do
        allow(CommandTower.config.login.plain_text.password_reset).to receive(:require_email).and_return(true)
      end

      context "when email is not provided" do
        let(:email) { nil }

        it "returns 400" do
          subject
          expect(response.status).to eq(400)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Email is required")
        end
      end

      context "when email is provided and matches" do
        let(:email) { user.email }

        it "returns 200" do
          subject
          expect(response.status).to eq(200)
        end

        it "updates user password" do
          subject
          expect(user.reload.authenticate(password)).to be_truthy
        end
      end

      context "when email is provided but does not match" do
        let(:email) { "wrong@example.com" }

        it "returns 401" do
          subject
          expect(response.status).to eq(401)
        end

        it "sets message" do
          subject
          expect(response_body["message"]).to eq("Invalid token")
        end
      end
    end
  end

  describe "POST: password_change_post" do
    subject(:password_change_post) { post(:password_change_post, params:) }

    let(:sentinel_current) { "HttpSentinelCurrent_Aa1!" }
    let(:sentinel_new) { "HttpSentinelNew_Bb2!" }
    let(:sentinel_wrong) { "HttpSentinelWrong_Cc3!" }

    let(:user) { create(:user, password: sentinel_current, password_confirmation: sentinel_current) }
    let(:current_password) { sentinel_current }
    let(:password) { sentinel_new }
    let(:password_confirmation) { password }
    let(:params) do
      {
        current_password:,
        password:,
        password_confirmation:,
      }.compact
    end

    def assert_response_no_secret_leak!
      body = response.body
      expect(body).not_to include(sentinel_current)
      expect(body).not_to include(sentinel_new)
      expect(body).not_to include(sentinel_wrong)
      expect(body).not_to include(user.reload.verifier_token) if user.verifier_token.present?
      expect(response_body).not_to have_key("token")
      expect(response_body).not_to have_key("verifier_token")
    end

    include_examples "Invalid/Missing JWT token on required route"

    context "with valid JWT and passwords" do
      before { set_jwt_token!(user:) }

      let!(:old_jwt) do
        user.retreive_verifier_token!
        CommandTower::Jwt::LoginCreate.(user: user.reload).token
      end

      it "returns 200" do
        subject
        expect(response.status).to eq(200)
        assert_response_no_secret_leak!
      end

      it "sets message" do
        subject
        expect(response_body["message"]).to eq("Password has been successfully changed")
        assert_response_no_secret_leak!
      end

      it "updates password and invalidates prior JWT" do
        subject
        expect(user.reload.authenticate(sentinel_new)).to be_truthy
        expect(CommandTower::Jwt::AuthenticateUser.(token: old_jwt).failure?).to eq(true)
      end
    end

    context "with incorrect current password" do
      before { set_jwt_token!(user:) }

      let(:current_password) { sentinel_wrong }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Incorrect current password", :current_password

      it "does not leak secrets" do
        subject
        assert_response_no_secret_leak!
      end
    end

    context "with password confirmation mismatch" do
      before { set_jwt_token!(user:) }

      let(:password_confirmation) { sentinel_wrong }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Password and confirmation do not match", :password_confirmation

      it "does not leak secrets" do
        subject
        assert_response_no_secret_leak!
      end
    end

    context "with password too short" do
      before { set_jwt_token!(user:) }

      let(:password) { "short" }
      let(:password_confirmation) { "short" }

      include_examples "CommandTower::Schema::Error:InvalidArguments examples", 400, "Password length must be between", :password

      it "does not leak secrets" do
        subject
        assert_response_no_secret_leak!
      end
    end
  end
end
