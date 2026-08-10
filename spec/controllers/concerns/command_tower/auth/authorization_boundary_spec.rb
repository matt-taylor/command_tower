# frozen_string_literal: true

RSpec.describe CommandTower::Auth::AuthorizationBoundary, type: :controller do
  controller(ActionController::API) do
    include CommandTower::Auth::AuthenticationBoundary
    include CommandTower::Auth::AuthorizationBoundary

    before_action :authenticate_request!
    before_action :authorize_request!

    def show
      render json: { ok: true }
    end
  end

  before do
    routes.draw do
      get "show" => "anonymous#show"
    end
  end

  describe "GET #show through the authorization boundary" do
    let(:user) { create(:user, roles: ["member"]) }

    before do
      allow(CommandTower::Workflows::Auth::AuthorizeRequestWorkflow).to receive(:call).and_return(authorize_result)
      request.headers["Authorization"] = "Bearer #{login_token_for(user)}"
      get :show
    end

    context "when authorization succeeds" do
      let(:authorize_result) do
        CommandTower::Workflows::WorkflowResult.success(payload: {}, http_status: :ok)
      end

      it { expect(response).to have_http_status(:ok) }

      it "asks the workflow about this controller and action" do
        expect(CommandTower::Workflows::Auth::AuthorizeRequestWorkflow).to have_received(:call).with(
          current_user: user,
          controller_class: controller.class,
          action_name: "show"
        )
      end
    end

    context "when authorization is denied" do
      let(:authorize_result) do
        CommandTower::Workflows::WorkflowResult.failure(
          errors: [CommandTower::Errors::ForbiddenError.new],
          http_status: :forbidden
        )
      end

      it { expect(response).to have_http_status(:forbidden) }

      it "returns forbidden in the envelope" do
        expect(response.parsed_body["errors"].first["code"]).to eq("forbidden")
      end

      it "halts before the action body" do
        expect(response.parsed_body["data"]).to be_nil
      end
    end
  end
end
