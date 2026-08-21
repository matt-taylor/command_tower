# frozen_string_literal: true

module CommandTower
  module Services
    module Impersonation
      class Create < CommandTower::Services::ApplicationService
        validate :actor, is_a: User, required: true
        validate :target, is_a: User, required: true

        def call
          now = Time.current
          idle = CommandTower.config.impersonation.idle_timeout
          absolute = CommandTower.config.impersonation.absolute_timeout

          session = CommandTower::Impersonation::Session.create!(
            actor_user_id: actor.id,
            target_user_id: target.id,
            started_at: now,
            last_activity_at: now,
            idle_expires_at: now + idle,
            absolute_expires_at: now + absolute
          )

          context.session = session
        end
      end
    end
  end
end
