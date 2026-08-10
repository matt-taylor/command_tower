# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Mappers
        class InboxItemMapper
          def self.to_result(inbox_item)
            return nil if inbox_item.nil?

            Results::InboxItemResult.new(id: inbox_item.id).freeze
          end
        end
      end
    end
  end
end
