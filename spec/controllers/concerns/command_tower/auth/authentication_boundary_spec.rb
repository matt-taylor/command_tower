# frozen_string_literal: true

RSpec.describe CommandTower::Auth::AuthenticationBoundary, type: :controller do
  controller(ActionController::API) do
    include CommandTower::Auth::AuthenticationBoundary

    before_action :authenticate_request!

    def show
      render json: {
        user_id: current_user.id,
        token_source: current_auth_context.token_source,
        principal_type: current_auth_context.principal_type
      }
    end
  end

  let(:jwt_cookie_name) { CommandTower.config.jwt.cookie.name }

  before do
    routes.draw do
      get "show" => "anonymous#show"
    end
  end

  describe "GET #show through the authentication boundary" do
    context "with a valid Bearer token" do
      let(:user) { create(:user) }

      before do
        request.headers["Authorization"] = "Bearer #{login_token_for(user)}"
        get :show
      end

      let(:body) { response.parsed_body }

      it { expect(response).to have_http_status(:ok) }

      it "populates current_user and current_auth_context" do
        expect(body["user_id"]).to eq(user.id)
        expect(body["token_source"]).to eq("header")
        expect(body["principal_type"]).to eq("user")
      end
    end

    context "without a token" do
      before { get :show }

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns unauthorized in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("unauthorized")
      end
    end

    context "with an unverified email" do
      let(:user) { create(:user, :unvalidated_email, created_at: 5.minutes.ago) }

      before do
        request.headers["Authorization"] = "Bearer #{login_token_for(user)}"
        get :show
      end

      it { expect(response).to have_http_status(:precondition_failed) }

      it "returns email_verification_required in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("email_verification_required")
      end
    end

    context "with invalid cookie authentication" do
      before do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = true
        end
        request.cookies[jwt_cookie_name] = "invalid-token"
        get :show
      end

      after do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = false
        end
      end

      let(:cookie_headers) { Array(response.headers["Set-Cookie"]).join }

      it { expect(response).to have_http_status(:unauthorized) }

      it "clears the auth cookie" do
        expect(cookie_headers).to include(jwt_cookie_name)
        expect(cookie_headers).to match(/expires=|max-age=0/i)
      end
    end
  end
end
