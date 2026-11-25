# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module DeviceSessions
        # Creates a device session for a successful login or registration. A new
        # session is created every time. An active session already held by the same
        # installation is revoked as `replaced`, so one device has one live session.
        class Start < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :installation_id, is_a: String
          validate :platform, is_a: String
          validate :app_version, is_a: String

          def call
            transaction do
              replace_installation_sessions!
              context.device_session = create_session!
            end
          end

          private

          def replace_installation_sessions!
            return if installation_id.blank?

            CommandTower::Auth::DeviceSession
              .active
              .where(user_id: user.id, installation_id: installation_id)
              .update_all(revoked_at: now, revoked_reason: "replaced", updated_at: now) # rubocop:disable Rails/SkipsModelValidations
          end

          def create_session!
            CommandTower::Auth::DeviceSession.create!(
              user: user,
              installation_id: installation_id.presence,
              platform: platform.presence,
              app_version: app_version.presence,
              last_seen_at: now,
              absolute_expires_at: now + CommandTower.config.session.absolute_timeout
            )
          end

          def now
            @now ||= Time.current
          end
        end
      end
    end
  end
end
