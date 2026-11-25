# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module DeviceSessions
        # Gives a sid-less legacy token a device session. The row is keyed by
        # (user, legacy_generated_at) under a unique index, so concurrent upgrades of
        # the same token converge on one row. The session expires at the token's
        # `generated_at` plus the absolute timeout.
        class UpgradeLegacy < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :legacy_generated_at, is_a: Integer, required: true
          validate :installation_id, is_a: String
          validate :platform, is_a: String
          validate :app_version, is_a: String

          def call
            context.device_session = CommandTower::Auth::DeviceSession.create_or_find_by!(
              user_id: user.id,
              legacy_generated_at: generated_at
            ) { |session| session.assign_attributes(new_session_attributes) }
          end

          private

          def new_session_attributes
            {
              installation_id: installation_id.presence,
              platform: platform.presence,
              app_version: app_version.presence,
              last_seen_at: Time.current,
              absolute_expires_at: generated_at + CommandTower.config.session.absolute_timeout
            }
          end

          def generated_at
            @generated_at ||= Time.zone.at(legacy_generated_at)
          end
        end
      end
    end
  end
end
