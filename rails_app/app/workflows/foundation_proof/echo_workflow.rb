# frozen_string_literal: true

module FoundationProof
  class EchoWorkflow < CommandTower::Workflows::ApplicationWorkflow
    retry_strategy :none

    EXPIRE_HEADER_VALUE = "foundation-proof-expire"

    def call(message:, limit:)
      result = EchoService.call(message: message, limit: limit)
      if result.failure?
        return failure(
          errors: result.errors,
          http_status: :unprocessable_entity
        )
      end

      success(
        payload: EchoSerializer.serialize(
          message: result.data[:message],
          limit: result.data[:limit]
        ),
        http_status: :ok,
        meta: { source: "foundation_proof" },
        response_effects: { set_expire_header: EXPIRE_HEADER_VALUE }
      )
    end
  end
end
