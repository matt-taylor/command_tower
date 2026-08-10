# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Requests
        FindCommunication = Data.define(
          :communication_id,
          :recipient_id,
        ) do
          def self.build(communication_id:, recipient_id: nil)
            new(
              communication_id:,
              recipient_id:,
            ).freeze
          end
        end
      end
    end
  end
end
