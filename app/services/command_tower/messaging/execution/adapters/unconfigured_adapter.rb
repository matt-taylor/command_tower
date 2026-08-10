# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        class UnconfiguredAdapter
          def call(request:)
            raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

            AdapterResult.build(
              outcome: :terminal_failure,
              error_code: "adapter_unconfigured",
            )
          end
        end
      end
    end
  end
end
