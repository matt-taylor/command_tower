# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      class AcceptRejectedError < CommandTower::Errors::ApplicationError
        def code
          "messaging_accept_rejected"
        end

        def message
          "Messaging accept was rejected"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
