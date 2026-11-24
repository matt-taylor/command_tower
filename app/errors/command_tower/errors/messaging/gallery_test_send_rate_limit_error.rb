# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      class GalleryTestSendRateLimitError < CommandTower::Errors::ApplicationError
        def initialize(retry_after_seconds: nil)
          super(details: retry_after_seconds ? { retry_after_seconds: retry_after_seconds } : nil)
        end

        def code
          "gallery_test_send_rate_limited"
        end

        def message
          "Too many gallery test sends. Please try again later."
        end

        def log_level
          :warn
        end
      end
    end
  end
end
