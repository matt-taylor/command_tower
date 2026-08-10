# frozen_string_literal: true

module CommandTower
  module Auth
    module PlainText
      class LoginController < CommandTower::ApplicationController
        include CommandTower::Api::ApplicationResponseRenderer
        include CommandTower::Auth::InvalidCredentialsDeserializerRenderer

        def create
          deserialized = CommandTower::Deserializers::Auth::PlainText::LoginDeserializer.call(params)
          return render_application_deserializer_errors(deserialized) unless deserialized.success?

          result = CommandTower::Workflows::Auth::PlainText::LoginWorkflow.call(
            input: deserialized.input
          )
          render_application_result(result)
        end
      end
    end
  end
end
