# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Observability
        module Correlation
          module_function

          def resolve
            CommandTower::Current.correlation_id.presence ||
              CommandTower::Current.request_id.presence ||
              SecureRandom.uuid
          end
        end
      end
    end
  end
end
