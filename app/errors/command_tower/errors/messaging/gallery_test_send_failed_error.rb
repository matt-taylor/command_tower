# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      # The email adapter did not accept the test message. Carries the adapter's error code only.
      class GalleryTestSendFailedError < CommandTower::Errors::ApplicationError
        def initialize(error_code: nil)
          super(details: error_code ? { error_code: error_code } : nil)
        end

        def code
          "gallery_test_send_failed"
        end

        def message
          "The test message could not be sent."
        end

        def log_level
          :warn
        end
      end
    end
  end
end
