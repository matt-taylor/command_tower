# frozen_string_literal: true

module CommandTower
  module Clients
    module Errors
      class UpstreamError < CommandTower::Errors::ApplicationError
        def initialize(message: nil, details: nil, cause: nil)
          @message = message
          super(details: details, cause: cause)
        end

        def code
          "upstream_error"
        end

        def message
          @message.presence || "Upstream request failed"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
