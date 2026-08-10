# frozen_string_literal: true

RSpec.describe CommandTower::Api::DeserializerFailureDetails, type: :controller do
  controller(ActionController::API) do
    include CommandTower::Api::ApplicationResponseRenderer
    include CommandTower::Api::DeserializerFailureDetails

    def create
      deserialized = CommandTower::Deserializers::Auth::PasswordReset::SendDeserializer.call(params)

      render_application_result(
        CommandTower::Workflows::WorkflowResult.failure(
          errors: [CommandTower::Errors::ValidationError.new(details: deserializer_failure_details(deserialized))],
          http_status: :unprocessable_entity
        )
      )
    end
  end

  before do
    routes.draw do
      post "create" => "anonymous#create"
    end
  end

  describe "a single hash failure" do
    before { post :create }

    it "renders the field map rather than an array wrapper" do
      expect(response.parsed_body["errors"].first["details"]).to eq("email" => "Email is required")
    end
  end
end
