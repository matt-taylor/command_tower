# frozen_string_literal: true

module CommandTower
  module Serializers
    module Intervention
      # Canonical remediation facts (presentation-independent). Host maps `action` to routes.
      class RemediationSerializer < CommandTower::Serializers::ApplicationSerializer
        def self.serialize(kind:, action:, label: nil)
          payload = {
            kind: kind.to_s,
            action: action.to_s
          }
          payload[:label] = label.to_s if label.present?
          payload
        end
      end
    end
  end
end
