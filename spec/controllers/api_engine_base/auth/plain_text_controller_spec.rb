# frozen_string_literal: true

RSpec.describe ApiEngineBase::Auth::PlainTextController, type: :controller do
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
    let(:username) { "d" + Faker::Lorem.characters(number: ApiEngineBase.config.username.username_length_max - 1) }
    let(:email) { Faker::Internet.email }
    let(:password) { Faker::Alphanumeric.alpha(number: 20) }
    let(:password_confirmation) { password }

    context "with invalid email" do
      let(:email) { "Invalid$emailaddy" }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Invalid email address", :email
    end

    context "with invalid username" do
      let(:username) { " this i!s my username " }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Username is invalid", :username
    end

    context "with invalid password" do
      let(:password_confirmation) { "does not equal" }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "doesn't match Password", :password_confirmation
    end

    context "with missing parameters" do
      context "multiple missing" do
        let(:first_name) { nil }
        let(:last_name) { nil }
        let(:password) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, ["[first_name]", "[first_name]", "[password]"], [:first_name, :first_name, :password]
      end

      context "with first_name" do
        let(:first_name) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [first_name]", :first_name
      end

      context "with last_name" do
        let(:last_name) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [last_name]", :last_name
      end

      context "with username" do
        let(:username) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [username]", :username
      end

      context "with email" do
        let(:email) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [email]", :email
      end

      context "with password" do
        let(:password) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [password]", :password
      end

      context "with password_confirmation" do
        let(:password_confirmation) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 400, "Parameter [password_confirmation]", :password_confirmation
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
      result = ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Generate.(user:)
      result.secret
    end
    let(:params) { { code: }.compact }
    let(:user) { create(:user, :unvalidated_email) }

    include_examples "Invalid/Missing JWT token on required route"

    context "with invalid code" do
      before { set_jwt_token!(user:) }
      let(:code) { "this is an incorrect code" }
      let(:user) { create(:user, :unvalidated_email) }

      include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 403, "Incorrect verification code provided", :code

      context "with mismatched code and user" do
        let(:incorrect_user) { create(:user, :unvalidated_email) }
        let(:code) do
          result = ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Generate.(user: incorrect_user)
          result.secret
        end

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 403, "Incorrect verification code provided", :code
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
        allow(ApiEngineBase::EmailVerificationMailer).to receive(:verify_email).and_raise(StandardError)
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
        username:,
        email:,
        password: password_input,
      }.compact
    end
    let(:user) { create(:user, password:) }
    let(:password) { Faker::Alphanumeric.alpha(number: 20) }
    let(:password_input) { password }
    let(:username) { nil }
    let(:email) { nil }

    context "with correct login" do
      context "with email" do
        let(:email) { user.email }

        it "returns success" do
          subject
          expect(response.status).to eq(201)
        end

        it "sets correct body" do
          subject
          expect(response_body["message"]).to eq("Successfully logged user in")
          expect(response_body["token"]).to be_present
          expect(response_body["header_name"]).to eq(ApiEngineBase::ApplicationController::AUTHENTICATION_HEADER)
        end
      end

      context "with username" do
        let(:username) { user.username }

        it "returns success" do
          subject
          expect(response.status).to eq(201)
        end

        it "sets correct body" do
          subject
          expect(response_body["message"]).to eq("Successfully logged user in")
          expect(response_body["token"]).to be_present
          expect(response_body["header_name"]).to eq(ApiEngineBase::ApplicationController::AUTHENTICATION_HEADER)
        end
      end
    end

    context "with incorrect arguments" do
      context "with both login keys provided" do
        let(:username) { user.username }
        let(:email) { user.email }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 401, "Composite Key failure for login_key", [:login_key]
      end

      context "when no login key provided" do
        let(:username) { nil }
        let(:email) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 401, "Composite Key failure for login_key", [:login_key]
      end

      context "with missing password" do
        let(:username) { user.username }
        let(:password_input) { nil }

        include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 401, "Parameter [password] is required but not present", [:password]
      end
    end

    context "when failed login" do
      context "with incorrect login key" do
        context "with email" do
          let(:email) { "not a valid email input" }
          include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 401, "Unauthorized Access. Incorrect Credentials", [:email, :password]
        end

        context "with username" do
          let(:username) { "not a valid email input" }
          include_examples "ApiEngineBase::Schema::Error:InvalidArguments examples", 401, "Unauthorized Access. Incorrect Credentials", [:username, :password]
        end
      end
    end
  end
end
