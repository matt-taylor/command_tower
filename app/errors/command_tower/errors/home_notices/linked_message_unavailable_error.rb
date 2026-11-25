# frozen_string_literal: true

module CommandTower
  module Errors
    module HomeNotices
      # A linked delivery named a communication the user cannot see in their inbox (missing, deleted,
      # foreign, or not backed by a message definition).
      class LinkedMessageUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "linked_message_unavailable"
        end

        def message
          "The linked message is unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
