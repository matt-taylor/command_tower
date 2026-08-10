# frozen_string_literal: true

module FoundationProof
  class EchoController < BaseController
    def create
      deserialized = EchoDeserializer.call(params)
      unless deserialized.success?
        return render_application_deserializer_failure(deserialized)
      end

      result = EchoWorkflow.call(
        message: deserialized.input.message,
        limit: deserialized.input.limit
      )
      render_application_result(result)
    end
  end
end
