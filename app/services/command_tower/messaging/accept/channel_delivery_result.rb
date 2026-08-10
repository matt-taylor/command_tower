# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      ChannelDeliveryResult = Data.define(:id, :channel_key, :status) do
        def self.build(id:, channel_key:, status:)
          new(id:, channel_key: channel_key.to_s, status: status.to_s).freeze
        end
      end
    end
  end
end
