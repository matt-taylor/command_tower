# frozen_string_literal: true

module CommandTower
  module Serializers
    module HomeNotices
      # The payload of a home-notice mutation (impression, acknowledge, dismiss): `{ recorded }`.
      class MutationSerializer
        # @param recorded [Boolean] true when the request changed state, false for a no-op
        #   (impersonation, or a repeat inside the idempotency window)
        def self.serialize(recorded:)
          { recorded: recorded == true }
        end
      end
    end
  end
end
