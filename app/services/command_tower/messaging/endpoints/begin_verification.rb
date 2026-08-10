# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class BeginVerification
        def self.call(owner_user_id:, endpoint_id:)
          VerificationTransition.call(owner_user_id:, endpoint_id:, to: "pending")
        end
      end
    end
  end
end
