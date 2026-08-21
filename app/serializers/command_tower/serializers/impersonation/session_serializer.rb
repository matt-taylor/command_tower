# frozen_string_literal: true

module CommandTower
  module Serializers
    module Impersonation
      class SessionSerializer < CommandTower::Serializers::ApplicationSerializer
        def self.serialize(session)
          {
            id: session.id,
            actorUserId: session.actor_user_id,
            targetUserId: session.target_user_id,
            idleExpiresAt: iso8601(session.idle_expires_at),
            absoluteExpiresAt: iso8601(session.absolute_expires_at)
          }
        end
      end
    end
  end
end
