# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class VerificationTransition
        def self.call(owner_user_id:, endpoint_id:, to:)
          record = Endpoint.for_owner(owner_user_id).lock.find_by(id: endpoint_id)
          raise NotFoundError, "endpoint not found" if record.nil?

          ChannelGate.assert_record_supported!(record)

          Verification.apply!(record, to:)
          record.save!
          SafeView.from_record(record)
        end
      end
    end
  end
end
