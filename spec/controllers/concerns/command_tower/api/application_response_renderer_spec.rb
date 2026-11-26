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

    def rate_limited_action
      result = CommandTower::Workflows::WorkflowResult.failure(
        errors: [CommandTower::Errors::Auth::AuthRateLimitedError.new(retry_after_seconds: 42)],
        http_status: :too_many_requests,
        response_effects: { retry_after: 42 }
      )
      render_application_result(result)
    end

    def deferred_action
      result = CommandTower::Workflows::WorkflowResult.deferred(
        reason: :provider_cooldown,
        retry_after: 17,
        payload: { pending: true }
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
      get "rate_limited_action" => "anonymous#rate_limited_action"
      get "deferred_action" => "anonymous#deferred_action"
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

    context "with a deferred result" do
      before { get :deferred_action }

      let(:body) { response.parsed_body }

      it { expect(response).to have_http_status(:accepted) }

      it "renders a success-shaped envelope, not errors" do
        expect(body["data"]).to eq("pending" => true)
        expect(body["errors"]).to eq([])
        expect(body["meta"]).to include("reason" => "provider_cooldown", "retry_after" => 17)
      end
    end

    context "with a retry_after effect on a rate-limited failure" do
      before { get :rate_limited_action }

      let(:error) { response.parsed_body["errors"].first }

      it { expect(response).to have_http_status(:too_many_requests) }

      it "sets the Retry-After header" do
        expect(response.headers["Retry-After"]).to eq("42")
      end

      it "renders auth_rate_limited with retry_after_seconds" do
        expect(error["code"]).to eq("auth_rate_limited")
        expect(error["details"]).to eq("retry_after_seconds" => 42)
      end
    end

    context "without a retry_after effect" do
      before { get :failure_action }

      it { expect(response.headers["Retry-After"]).to be_nil }
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
