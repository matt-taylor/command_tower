# frozen_string_literal: true

module CommandTower
  module AuditEventHelpers
    def create_audit_event!(**overrides)
      CommandTower::Audit::Event.create!(
        {
          event_uuid: SecureRandom.uuid,
          action: "password_changed",
          occurred_at: Time.utc(2026, 8, 16, 12, 0, 0),
          attribution_mode: "self_service",
          impersonation_active: false,
          scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
          change_set: {},
          metadata: {},
          user_history: true,
          sensitive_fields: [],
          retention: "permanent"
        }.merge(overrides)
      )
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::AuditEventHelpers
end
