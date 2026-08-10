# frozen_string_literal: true

RSpec.describe CommandTower::Auth::PasswordRecoverySessionBoundary, type: :controller do
  controller(ActionController::API) do
    include CommandTower::Auth::PasswordRecoverySessionBoundary

    before_action :authenticate_password_recovery_session!

    def create
      render json: {
        jti: current_password_recovery_session.jti,
        client_ip: current_password_recovery_session.client_ip
      }
    end
  end

  before do
    routes.draw do
      post "create" => "anonymous#create"
    end
  end

  describe "POST #create through the recovery session boundary" do
    context "with a valid recovery session token" do
      let(:recovery_session) { password_recovery_session_context }
      let(:workflow_result) do
        CommandTower::Workflows::WorkflowResult.success(
          payload: { password_recovery_session: recovery_session },
          http_status: :ok
        )
      end

      before do
        request.headers["Authorization"] = "Recovery some-token"
        allow(CommandTower::Workflows::Auth::PasswordRecoverySession::AuthenticateWorkflow)
          .to receive(:call).and_return(workflow_result)
        post :create
      end

      it { expect(response).to have_http_status(:ok) }

      it "delegates to AuthenticateWorkflow" do
        expect(CommandTower::Workflows::Auth::PasswordRecoverySession::AuthenticateWorkflow)
          .to have_received(:call).with(request: request)
      end

      it "populates current_password_recovery_session" do
        expect(response.parsed_body["jti"]).to eq(recovery_session.jti)
        expect(response.parsed_body["client_ip"]).to eq(recovery_session.client_ip)
      end
    end

    context "without a recovery session token" do
      before { post :create }

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns password_recovery_session_missing in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("password_recovery_session_missing")
      end
    end

    context "with a Bearer scheme" do
      before do
        request.headers["Authorization"] = "Bearer sometoken"
        post :create
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns password_recovery_session_invalid in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("password_recovery_session_invalid")
      end
    end
  end
end
