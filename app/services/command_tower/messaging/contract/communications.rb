# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Communications
        class << self
          def find(request)
            ensure_request!(request, Requests::FindCommunication)
            Observability::OperationLogger.around(
              operation: "communications.find",
              request:,
            ) do
              Internal::Finder.call(request)
            end
          end

          private

          def ensure_request!(request, expected_class)
            return if request.is_a?(expected_class)

            raise Contract::ValidationError, "expected #{expected_class}, got #{request.class}"
          end
        end
      end
    end
  end
end
