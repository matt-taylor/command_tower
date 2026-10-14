# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      UnreadCountResult = Data.define(:recipient_id, :count, :badge_count) do
        def self.build(recipient_id:, count:, badge_count:)
          new(
            recipient_id:,
            count: Integer(count),
            badge_count: Integer(badge_count),
          ).freeze
        end
      end
    end
  end
end
