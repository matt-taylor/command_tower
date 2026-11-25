# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Requests
        # impersonating follows the renderer: anything but exactly false redacts `code` values.
        DocumentForCommunication = Data.define(
          :communication_id,
          :recipient_id,
          :impersonating
        ) do
          def self.build(communication_id:, recipient_id:, impersonating: nil)
            new(
              communication_id:,
              recipient_id:,
              impersonating:
            ).freeze
          end
        end
      end
    end
  end
end
