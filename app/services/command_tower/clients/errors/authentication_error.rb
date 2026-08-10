# frozen_string_literal: true

module CommandTower
  module Clients
    module Errors
      class AuthenticationError < CommandTower::Errors::ApplicationError
        def initialize(message: nil, details: nil, cause: nil)
          @message = message
          super(details: details, cause: cause)
        end

        def code
          "authentication_error"
        end

        def message
          @message.presence || "Client authentication failed"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
