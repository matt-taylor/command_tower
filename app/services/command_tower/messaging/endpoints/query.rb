# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class Query
        def self.list(owner_user_id:, channel_key: nil)
          if channel_key
            ChannelGate.assert_endpoint_backed!(channel_key)
          end

          scope = Endpoint.for_owner(owner_user_id).order(:id)
          scope = scope.where(channel_key: ChannelGate.supported_channel_keys)
          scope = scope.for_channel(channel_key) if channel_key
          scope.map { |record| SafeView.from_record(record) }
        end

        def self.show(owner_user_id:, endpoint_id:)
          record = Endpoint.for_owner(owner_user_id).find_by(id: endpoint_id)
          raise NotFoundError, "endpoint not found" if record.nil?

          ChannelGate.assert_record_supported!(record)
          SafeView.from_record(record)
        end
      end
    end
  end
end
