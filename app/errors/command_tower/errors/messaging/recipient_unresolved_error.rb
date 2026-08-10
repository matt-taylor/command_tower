# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      class RecipientUnresolvedError < CommandTower::Errors::ApplicationError
        def code
          "messaging_recipient_unresolved"
        end

        def message
          "Unable to resolve messaging recipient"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
