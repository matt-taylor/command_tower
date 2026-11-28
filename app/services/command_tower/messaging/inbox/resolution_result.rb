# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # Outcome of resolving or unresolving one inbox item. changed is true only for
      # the call that flipped resolved_at.
      ResolutionResult = Data.define(
        :communication_id,
        :inbox_item_id,
        :resolved,
        :changed
      )
    end
  end
end
