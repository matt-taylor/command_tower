# frozen_string_literal: true

module CommandTower
  module Messaging
    module RecipientReadiness
      RecipientResult = Data.define(
        :recipient_id,
        :channels,
        :evaluated_at,
      ) do
        def self.build(recipient_id:, channels:, evaluated_at: Time.current)
          frozen_channels =
            channels.to_h do |key, result|
              [key.to_s, result]
            end.freeze

          new(
            recipient_id:,
            channels: frozen_channels,
            evaluated_at:,
          ).freeze
        end

        def channel(key)
          channels[key.to_s]
        end

        def ready_channel_keys
          channels.select { |_key, result| result.ready }.keys.freeze
        end

        def recipient_ready_channel_keys
          channels.select { |_key, result| result.recipient_ready }.keys.freeze
        end
      end
    end
  end
end
