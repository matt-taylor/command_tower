# frozen_string_literal: true

module CommandTower
  module Serializers
    module Intervention
      # One presentation-independent blocker fact. No presentation mode / routes / host policy.
      class BlockerSerializer < CommandTower::Serializers::ApplicationSerializer
        def self.serialize(code:, action:, title:, message:, remediation: nil, severity: nil)
          payload = {
            code: code.to_s,
            action: action.to_s,
            title: title.to_s,
            message: message.to_s
          }
          payload[:severity] = severity.to_s if severity.present?
          if remediation
            payload[:remediation] = RemediationSerializer.serialize(**remediation)
          end
          payload
        end
      end
    end
  end
end
