# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      AdapterRequest = Data.define(
        :channel_delivery_id,
        :communication_id,
        :channel_key,
        :attempt_id,
        :rendered,
      ) do
        def self.build(channel_delivery_id:, communication_id:, channel_key:, attempt_id:, rendered:)
          raise InvalidAdapterContractError, "arbitrary hashes are not accepted" if [channel_delivery_id, communication_id, channel_key, attempt_id].any? { |v| v.is_a?(Hash) }
          raise InvalidAdapterContractError, "channel_delivery_id is required" if blank?(channel_delivery_id)
          raise InvalidAdapterContractError, "communication_id is required" if blank?(communication_id)
          raise InvalidAdapterContractError, "attempt_id is required" if blank?(attempt_id)
          raise InvalidAdapterContractError, "channel_key is required" if blank?(channel_key)
          raise InvalidAdapterContractError, "channel_key must be a String" unless channel_key.is_a?(String)
          raise InvalidAdapterContractError, "rendered is required" if rendered.nil?
          unless rendered.is_a?(Rendering::RenderedPayload) ||
              rendered.is_a?(Rendering::RenderedSmsPayload) ||
              rendered.is_a?(Rendering::RenderedPushoverPayload)
            raise InvalidAdapterContractError,
                  "rendered must be a RenderedPayload, RenderedSmsPayload, or RenderedPushoverPayload"
          end
          raise InvalidAdapterContractError, "rendered must be frozen" unless rendered.frozen?

          new(
            channel_delivery_id:,
            communication_id:,
            channel_key:,
            attempt_id:,
            rendered:,
          ).freeze
        end

        def self.blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
        private_class_method :blank?
      end
    end
  end
end
