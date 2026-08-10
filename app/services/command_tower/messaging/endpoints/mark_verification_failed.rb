# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class MarkVerificationFailed
        def self.call(owner_user_id:, endpoint_id:)
          VerificationTransition.call(owner_user_id:, endpoint_id:, to: "failed")
        end
      end
    end
  end
end
