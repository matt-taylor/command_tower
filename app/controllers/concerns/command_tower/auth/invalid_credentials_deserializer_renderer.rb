# frozen_string_literal: true

module CommandTower
  module Auth
    # Auth-only mapping: deserializer failure → InvalidCredentials + 401.
    # Do not use ApplicationResponseRenderer#render_application_deserializer_failure
    # (ValidationError + 422) for login.
    module InvalidCredentialsDeserializerRenderer
      extend ActiveSupport::Concern

      private

      def render_application_deserializer_errors(_deserialized)
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::Auth::InvalidCredentialsError.new],
            http_status: :unauthorized
          )
        )
      end
    end
  end
end
