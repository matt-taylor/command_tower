# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module SignupRateLimits
        class CheckAvailability < CommandTower::Services::ApplicationService
          KINDS = %i[email username].freeze

          include Enforcement

          validate :signup_session, is_a: CommandTower::Auth::SignupSessionContext, required: true
          validate :kind, is_one: KINDS, required: true

          def call
            remaining = signup_session.remaining_seconds
            expired_session! if remaining <= 0

            jti_ttl = remaining + CommandTower.config.signup_session.cleanup_buffer_seconds

            enforce!(
              key: "signup:rate:jti:#{signup_session.jti}:#{kind}",
              ttl_seconds: jti_ttl,
              limit: kind == :email ? limits.jti_email : limits.jti_username,
              scope: :session
            )

            enforce!(
              key: "signup:rate:jti:#{signup_session.jti}:total",
              ttl_seconds: jti_ttl,
              limit: limits.jti_total,
              scope: :session
            )

            enforce!(
              key: "signup:rate:ip:#{normalize_ip(signup_session.client_ip)}:availability:1h:#{hour_bucket}",
              ttl_seconds: 3600,
              limit: limits.ip_availability_hour,
              scope: :ip
            )
          end

          private

          def expired_session!
            context.fail!(application_error: CommandTower::Errors::Auth::SignupSessionExpiredError.new)
          end
        end
      end
    end
  end
end
