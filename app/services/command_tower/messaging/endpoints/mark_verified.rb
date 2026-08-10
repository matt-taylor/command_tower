# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      class MarkVerified
        def self.call(owner_user_id:, endpoint_id:)
          VerificationTransition.call(owner_user_id:, endpoint_id:, to: "verified")
        end
      end
    end
  end
end
