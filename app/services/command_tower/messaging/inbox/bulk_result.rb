# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      BulkResult = Data.define(:ids, :count, :changed_count) do
        def self.build(ids:, changed_count:)
          ids = Array(ids).freeze

          new(
            ids:,
            count: ids.size,
            changed_count: Integer(changed_count),
          ).freeze
        end
      end
    end
  end
end
