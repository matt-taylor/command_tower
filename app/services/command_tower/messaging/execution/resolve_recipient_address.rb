# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      # Transport address only — eligibility / endpoint selection is owned by RecipientReadiness.
      class ResolveRecipientAddress
        E164 = /\A\+[1-9]\d{1,14}\z/

        def self.call(communication:, channel_key:, readiness_result: nil)
          new(communication:, channel_key:, readiness_result:).call
        end

        def initialize(communication:, channel_key:, readiness_result: nil)
          @communication = communication
          @channel_key = channel_key
          @readiness_result = readiness_result
        end

        def call
          case @channel_key.to_s
          when "sms"
            phone = @communication&.user&.phone_number.to_s.strip
            if blank_recipient?(phone)
              { address: nil, error_code: "recipient_missing" }
            elsif !phone.match?(E164)
              { address: nil, error_code: "invalid_recipient" }
            else
              { address: phone, error_code: nil }
            end
          when "email"
            address = @communication&.user&.email
            if blank_recipient?(address)
              { address: nil, error_code: "recipient_missing" }
            else
              { address:, error_code: nil }
            end
          when "pushover"
            endpoint_id = @readiness_result&.resolved_endpoint_id
            if endpoint_id.nil?
              { address: nil, error_code: "recipient_missing" }
            else
              { address: endpoint_id.to_s, error_code: nil }
            end
          else
            { address: nil, error_code: "adapter_unconfigured" }
          end
        end

        private

        def blank_recipient?(recipient_address)
          recipient_address.nil? || recipient_address.to_s.strip.empty?
        end
      end
    end
  end
end
