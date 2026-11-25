# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class PurgeUserAssociatedData < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true

        def call
          purge_user_secrets!
          purge_messaging_inbox!
          purge_messaging_endpoints!
          purge_home_notices!
          revoke_impersonation_sessions!
        end

        private

        # Per-user notice state only. Audit events (home_notice_acknowledged) are a separate record and stay.
        def purge_home_notices!
          CommandTower::HomeNotice.where(user_id: user.id).delete_all
        end

        def purge_user_secrets!
          UserSecret.where(user_id: user.id).delete_all
        end

        def purge_messaging_inbox!
          item_ids = CommandTower::Messaging::Inbox::Scope.for_recipient(user.id).pluck(:id)
          return if item_ids.empty?

          CommandTower::Messaging::Inbox.bulk_delete(recipient_id: user.id, inbox_item_ids: item_ids)
        end

        def purge_messaging_endpoints!
          return unless defined?(CommandTower::Messaging::Endpoint)

          CommandTower::Messaging::Endpoint.where(user_id: user.id).find_each(&:destroy!)
        end

        def revoke_impersonation_sessions!
          CommandTower::Services::Impersonation::TerminateOpenSessions.call(
            actor_user_id: user.id,
            reason: "revoked"
          )

          CommandTower::Impersonation::Session.open.where(target_user_id: user.id).find_each do |session|
            CommandTower::Services::Impersonation::End.call(
              session_id: session.id,
              reason: "revoked"
            )
          end
        end
      end
    end
  end
end
