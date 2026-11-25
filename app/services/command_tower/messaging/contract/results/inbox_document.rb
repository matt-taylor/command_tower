# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Results
        # The catalog 2 document (a CommandTower::UI::Document, already redacted per the
        # request's impersonating flag) of a definition-backed communication's inbox item.
        InboxDocument = Data.define(
          :communication_id,
          :inbox_item_id,
          :document
        )
      end
    end
  end
end
