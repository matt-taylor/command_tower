# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class Revoke
        def self.call(owner_user_id:, endpoint_id:)
          new(owner_user_id:, endpoint_id:).call
        end

        def initialize(owner_user_id:, endpoint_id:)
          @owner_user_id = owner_user_id
          @endpoint_id = endpoint_id
        end

        def call
          record = Endpoint.for_owner(@owner_user_id).find_by(id: @endpoint_id)
          raise NotFoundError, "endpoint not found" if record.nil?

          ChannelGate.assert_record_supported!(record)

          case record.lifecycle_state
          when "revoked", "retired"
            return SafeView.from_record(record)
          when "invalid"
            Lifecycle.apply!(record, to: "retired")
            record.save!
            return SafeView.from_record(record)
          when "active"
            Lifecycle.apply!(record, to: "revoked")
            record.save!
            SafeView.from_record(record)
          else
            raise InvalidTransitionError, "cannot revoke from #{record.lifecycle_state.inspect}"
          end
        end
      end
    end
  end
end
