# frozen_string_literal: true

module CommandTower
  module Serializers
    module Intervention
      # Action-scoped intervention envelope for GET projections and mutation errors.
      # `blockers` ordered; primary is first. No presentation-mode fields.
      # Host/CT FE owns presentation modes (callout, intercept, sheet, blocking_region).
      class EnvelopeSerializer < CommandTower::Serializers::ApplicationSerializer
        def self.serialize(action:, allowed:, blockers: [])
          {
            action: action.to_s,
            allowed: allowed == true,
            blockers: map_serialize(blockers) { |blocker| BlockerSerializer.serialize(**blocker) }
          }
        end

        def self.serialize_many(envelopes)
          map_serialize(envelopes) { |envelope| serialize(**envelope) }
        end
      end
    end
  end
end
