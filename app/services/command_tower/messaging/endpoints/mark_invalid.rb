# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class MarkInvalid
        def self.call(owner_user_id:, endpoint_id:)
          new(owner_user_id:, endpoint_id:).call
        end

        def initialize(owner_user_id:, endpoint_id:)
          @owner_user_id = owner_user_id
          @endpoint_id = endpoint_id
        end

        def call
          record = Endpoint.for_owner(@owner_user_id).lock.find_by(id: @endpoint_id)
          raise NotFoundError, "endpoint not found" if record.nil?

          ChannelGate.assert_record_supported!(record)

          return SafeView.from_record(record) if record.lifecycle_state == "invalid"
          return SafeView.from_record(record) if record.lifecycle_state == "retired"

          Lifecycle.apply!(record, to: "invalid")
          record.save!
          SafeView.from_record(record)
        end
      end
    end
  end
end
