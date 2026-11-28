# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # viewed_ids: every available requested id. newly_viewed: [{ id:, communication_id: }] for first views only.
      # unavailable_ids: missing, foreign and deleted ids, lumped with no per-id reason.
      RecordViewsResult = Data.define(:viewed_ids, :newly_viewed, :unavailable_ids)
    end
  end
end
