# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Results
        # Outcome of resolving or unresolving a communication's inbox item. changed is
        # true only for the call that flipped resolved_at.
        InboxResolution = Data.define(
          :communication_id,
          :inbox_item_id,
          :resolved,
          :changed
        )
      end
    end
  end
end
