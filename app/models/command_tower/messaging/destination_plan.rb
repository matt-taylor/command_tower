# frozen_string_literal: true

module CommandTower
  module Messaging
    class DestinationPlan < CommandTower::ApplicationRecord
      self.table_name = "messaging_destination_plans"

      belongs_to :communication,
                 class_name: "CommandTower::Messaging::Communication",
                 inverse_of: :destination_plan

      serialize :decision, coder: JSON, type: Hash

      validates :communication_id, uniqueness: true
    end
  end
end
