# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Mappers
        class DestinationPlanMapper
          def self.to_result(plan)
            return nil if plan.nil?

            Results::DestinationPlanResult.new(id: plan.id).freeze
          end
        end
      end
    end
  end
end
