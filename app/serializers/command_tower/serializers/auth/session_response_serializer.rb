# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class SessionResponseSerializer
        def self.serialize(user:, token_expires_at:, impersonation_session: nil, actor: nil)
          payload = {
            user: CommandTower::Serializers::Auth::UserSerializer.serialize(user),
            tokenExpiresAt: token_expires_at
          }
          return payload if impersonation_session.nil?

          actor_user = actor || impersonation_session.actor
          payload[:impersonation] = {
            active: true,
            sessionId: impersonation_session.id,
            actorUserId: impersonation_session.actor_user_id,
            actorDisplayName: display_name(actor_user),
            targetUserId: impersonation_session.target_user_id,
            idleExpiresAt: CommandTower::Serializers::ApplicationSerializer.iso8601(
              impersonation_session.idle_expires_at
            ),
            absoluteExpiresAt: CommandTower::Serializers::ApplicationSerializer.iso8601(
              impersonation_session.absolute_expires_at
            )
          }
          payload
        end

        def self.display_name(user)
          return nil if user.nil?

          [user.first_name, user.last_name].compact_blank.join(" ").presence || user.username
        end
        private_class_method :display_name
      end
    end
  end
end
