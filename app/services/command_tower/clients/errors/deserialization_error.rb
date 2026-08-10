# frozen_string_literal: true

module CommandTower
  module Clients
    module Errors
      class DeserializationError < CommandTower::Errors::ApplicationError
        def initialize(message: nil, details: nil, cause: nil)
          @message = message
          super(details: details, cause: cause)
        end

        def code
          "deserialization_error"
        end

        def message
          @message.presence || "Failed to deserialize upstream response"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
