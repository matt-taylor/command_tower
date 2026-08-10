# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # Raised when a bulk request references items the recipient cannot mutate:
      # unknown ids, another recipient's ids, or ids unavailable for the operation.
      # Carries the offending ids so callers can report them without parsing the message.
      class InvalidBulkItemsError < ValidationError
        attr_reader :invalid_ids

        def initialize(message = "inbox items are unavailable", invalid_ids: [])
          @invalid_ids = Array(invalid_ids).freeze
          super(message)
        end
      end
    end
  end
end
