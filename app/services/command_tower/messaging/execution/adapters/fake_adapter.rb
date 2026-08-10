# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        class FakeAdapter
          attr_reader :last_request

          def initialize(outcome: :success, normalized_provider_status: nil, provider_message_id: nil, error_code: nil)
            @outcome = outcome
            @normalized_provider_status = normalized_provider_status
            @provider_message_id = provider_message_id
            @error_code = error_code
            @last_request = nil
          end

          def call(request:)
            raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

            @last_request = request

            AdapterResult.build(
              outcome: @outcome,
              normalized_provider_status: @normalized_provider_status,
              provider_message_id: @provider_message_id || "fake-#{request.attempt_id}",
              error_code: @error_code,
            )
          end
        end
      end
    end
  end
end
