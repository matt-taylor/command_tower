# frozen_string_literal: true

RSpec.describe CommandTower::Api::ApplicationResponseRenderer, type: :controller do
  controller(ActionController::API) do
    include CommandTower::Api::ApplicationResponseRenderer

    def success_action
      result = CommandTower::Workflows::WorkflowResult.success(
        payload: { ok: true },
        http_status: :ok
      )
      render_application_result(result)
    end

    def success_with_expire_action
      result = CommandTower::Workflows::WorkflowResult.success(
        payload: { ok: true },
        http_status: :ok,
        response_effects: { set_expire_header: "expire-value" }
      )
      render_application_result(result)
    end

    def success_with_blank_effects_action
      result = CommandTower::Workflows::WorkflowResult.success(
        payload: { ok: true },
        http_status: :ok,
        response_effects: {}
      )
      render_application_result(result)
    end

    def success_with_unknown_effects_action
      result = CommandTower::Workflows::WorkflowResult.success(
        payload: { ok: true },
        http_status: :ok,
        response_effects: { totally_unknown_effect: true }
      )
      render_application_result(result)
    end

    def failure_action
      result = CommandTower::Workflows::WorkflowResult.failure(
        errors: [CommandTower::Errors::UnauthorizedError.new],
        http_status: :unauthorized
      )
      render_application_result(result)
    end

    def deser_failure_action
      deserialized = CommandTower::Deserializers::ApplicationDeserializer::DeserializerResult.new(
        success: false,
        errors: [{ code: "invalid_limit", field: "limit", details: {} }]
      )
      render_application_deserializer_failure(deserialized)
    end
  end

  before do
    routes.draw do
      get "success_action" => "anonymous#success_action"
      get "success_with_expire_action" => "anonymous#success_with_expire_action"
      get "success_with_blank_effects_action" => "anonymous#success_with_blank_effects_action"
      get "success_with_unknown_effects_action" => "anonymous#success_with_unknown_effects_action"
      get "failure_action" => "anonymous#failure_action"
      get "deser_failure_action" => "anonymous#deser_failure_action"
    end
  end

  describe "#render_application_result" do
    context "with a success result" do
      before { get :success_action }

      let(:body) { response.parsed_body }

      it { expect(response).to have_http_status(:ok) }

      it "renders the success envelope" do
        expect(body["data"]).to eq("ok" => true)
        expect(body["meta"]).to eq({})
        expect(body["errors"]).to eq([])
      end
    end

    context "with set_expire_header effect" do
      before { get :success_with_expire_action }

      it "sets the expire header" do
        expect(response.headers[CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER])
          .to eq("expire-value")
      end

      it "still renders successfully" do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq("ok" => true)
      end
    end

    context "with blank effects" do
      before { get :success_with_blank_effects_action }

      it "does nothing and still renders" do
        expect(response).to have_http_status(:ok)
        expect(response.headers[CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER]).to be_nil
      end
    end

    context "with unknown effects" do
      before { get :success_with_unknown_effects_action }

      it "does not raise and still renders" do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq("ok" => true)
      end
    end

    context "with a failure result" do
      before { get :failure_action }

      let(:error) { response.parsed_body["errors"].first }

      it { expect(response).to have_http_status(:unauthorized) }

      it "serializes errors into the envelope" do
        expect(error).to eq(
          "code" => "unauthorized",
          "message" => "Unauthorized"
        )
      end
    end
  end

  describe "#render_application_deserializer_failure" do
    before { get :deser_failure_action }

    let(:error) { response.parsed_body["errors"].first }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "preserves failure entries in ValidationError details" do
      expect(error["code"]).to eq("validation_failed")
      expect(error["details"]["failures"]).to contain_exactly(
        "code" => "invalid_limit",
        "field" => "limit",
        "details" => {}
      )
    end
  end
end
