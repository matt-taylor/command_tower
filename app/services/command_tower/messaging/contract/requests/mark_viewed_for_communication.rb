# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Requests
        MarkViewedForCommunication = Data.define(
          :communication_id,
          :recipient_id
        ) do
          def self.build(communication_id:, recipient_id:)
            new(
              communication_id:,
              recipient_id:
            ).freeze
          end
        end
      end
    end
  end
end
