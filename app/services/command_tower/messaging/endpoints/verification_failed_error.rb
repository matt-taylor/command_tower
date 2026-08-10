# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      # Raised after mark_verification_failed when the provider rejected validate/test.
      # Carries a safe error_code for host mapping; never includes secrets or raw provider bodies.
      class VerificationFailedError < Error
        attr_reader :error_code

        def initialize(error_code:, message: "Pushover verification failed")
          @error_code = error_code.to_sym
          super(message)
        end
      end
    end
  end
end
