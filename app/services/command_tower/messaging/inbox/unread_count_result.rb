# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      UnreadCountResult = Data.define(:recipient_id, :count) do
        def self.build(recipient_id:, count:)
          new(
            recipient_id:,
            count: Integer(count),
          ).freeze
        end
      end
    end
  end
end
