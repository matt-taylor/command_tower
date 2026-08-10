# frozen_string_literal: true

module CommandTower
  module Messaging
    module Pushover
      # Provider-call result. Never includes secrets or raw provider payloads.
      Result = Struct.new(
        :success?,
        :error_code,
        :error_message,
        :provider_request_id,
        keyword_init: true,
      ) do
        def self.ok(provider_request_id: nil)
          new(
            success?: true,
            error_code: nil,
            error_message: nil,
            provider_request_id: provider_request_id&.to_s.presence,
          )
        end

        def self.failure(error_code:, error_message:, provider_request_id: nil)
          new(
            success?: false,
            error_code: error_code.to_sym,
            error_message: error_message.to_s,
            provider_request_id: provider_request_id&.to_s.presence,
          )
        end
      end
    end
  end
end
