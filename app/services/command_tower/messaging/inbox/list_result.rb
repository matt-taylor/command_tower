# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      ListResult = Data.define(:items, :limit, :offset, :total_count) do
        def self.build(items:, limit:, offset:, total_count:)
          new(
            items: Array(items).freeze,
            limit: Integer(limit),
            offset: Integer(offset),
            total_count: Integer(total_count),
          ).freeze
        end
      end
    end
  end
end
