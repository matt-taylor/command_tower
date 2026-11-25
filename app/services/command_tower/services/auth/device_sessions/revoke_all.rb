# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module DeviceSessions
        # Ends every active device session of a user, including the caller's own.
        # Used when credentials change or the account is removed. Idempotent:
        # already-revoked sessions keep their original revoked_at and reason.
        class RevokeAll < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :reason, is_a: String, required: true

          def call
            unless CommandTower::Auth::DeviceSession::REVOKED_REASONS.include?(reason)
              raise ArgumentError, "Unknown device session revoke reason [#{reason}]"
            end

            now = Time.current
            scope = CommandTower::Auth::DeviceSession.active.where(user_id: user.id)
            context.revoked_count = scope.update_all(revoked_at: now, revoked_reason: reason, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
          end
        end
      end
    end
  end
end
