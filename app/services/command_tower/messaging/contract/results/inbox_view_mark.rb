# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Results
        # Outcome of marking a communication's inbox item viewed. newly_viewed is
        # true only for the call that set viewed_at (first view).
        InboxViewMark = Data.define(
          :communication_id,
          :inbox_item_id,
          :viewed,
          :newly_viewed
        )
      end
    end
  end
end
