# frozen_string_literal: true

module CommandTower
  module Services
    module Impersonation
      class RecordActivity < CommandTower::Services::ApplicationService
        validate :session_id, is_a: String, required: true

        def call
          now = Time.current
          idle = CommandTower.config.impersonation.idle_timeout
          CommandTower::Impersonation::Session.transaction do
            session = CommandTower::Impersonation::Session.lock.find_by(id: session_id)
            if session.nil? || !session.open? || session.expired?(at: now)
              context.refreshed = false
              return
            end

            session.update!(
              last_activity_at: now,
              idle_expires_at: now + idle
            )
            context.refreshed = true
            context.session = session
          end
        end
      end
    end
  end
end
