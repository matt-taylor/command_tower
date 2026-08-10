# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module ChannelGate
        module_function

        def assert_endpoint_backed!(channel_key)
          key = channel_key.to_s
          definition = Channels.fetch(key)
          if definition.nil?
            raise ValidationError, "unknown channel: #{key.inspect}"
          end
          unless definition.supports_endpoint_records
            raise ValidationError,
                  "channel #{key.inspect} does not support endpoint records"
          end

          definition
        end

        # Historical unsupported rows must not be exposed via show/mutate/verify.
        def assert_record_supported!(record)
          definition = Channels.fetch(record.channel_key)
          unless definition&.supports_endpoint_records
            raise NotFoundError, "endpoint not found"
          end

          definition
        end

        def supported_channel_keys
          Channels.definitions.select(&:supports_endpoint_records).map(&:key).freeze
        end
      end
    end
  end
end
