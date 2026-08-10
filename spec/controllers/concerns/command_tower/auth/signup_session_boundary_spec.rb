# frozen_string_literal: true

RSpec.describe CommandTower::Auth::SignupSessionBoundary, type: :controller do
  controller(ActionController::API) do
    include CommandTower::Auth::SignupSessionBoundary

    before_action :authenticate_signup_session!

    def show
      render json: {
        jti: current_signup_session.jti,
        client_ip: current_signup_session.client_ip
      }
    end
  end

  before do
    routes.draw do
      get "show" => "anonymous#show"
    end
  end

  describe "GET #show through the signup session boundary" do
    context "with a valid signup session token" do
      let(:signup_session) { signup_session_context }
      let(:workflow_result) do
        CommandTower::Workflows::WorkflowResult.success(
          payload: { signup_session: signup_session },
          http_status: :ok
        )
      end

      before do
        request.headers["Authorization"] = "Signup some-token"
        allow(CommandTower::Workflows::Auth::SignupSession::AuthenticateWorkflow)
          .to receive(:call).and_return(workflow_result)
        get :show
      end

      it { expect(response).to have_http_status(:ok) }

      it "delegates to AuthenticateWorkflow" do
        expect(CommandTower::Workflows::Auth::SignupSession::AuthenticateWorkflow)
          .to have_received(:call).with(request: request)
      end

      it "populates current_signup_session" do
        expect(response.parsed_body["jti"]).to eq(signup_session.jti)
        expect(response.parsed_body["client_ip"]).to eq(signup_session.client_ip)
      end
    end

    context "without a signup session token" do
      before { get :show }

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns signup_session_missing in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("signup_session_missing")
      end
    end

    context "with a malformed authorization scheme" do
      before do
        request.headers["Authorization"] = "Bearer sometoken"
        get :show
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns signup_session_invalid in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("signup_session_invalid")
      end
    end

    context "with an unparseable signup session token" do
      before do
        request.headers["Authorization"] = "Signup invalid-token"
        get :show
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns signup_session_invalid in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("signup_session_invalid")
      end
    end
  end
end
