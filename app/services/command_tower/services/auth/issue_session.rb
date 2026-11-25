# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      # Issues a signed-in session: starts the device session, then mints a token
      # carrying its `sid`. Login and registration share this sequence.
      class IssueSession < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true
        validate :installation_id, is_a: String
        validate :platform, is_a: String
        validate :app_version, is_a: String

        def call
          context.device_session = start_device_session
          context.token = mint_token(context.device_session)
          context.expires_at = token_expires_at
          install_installation_cookie(context.device_session)
        end

        private

        def token_expires_at
          CommandTower.config.jwt.ttl.from_now.to_time.to_s
        end

        def mint_token(device_session)
          CommandTower::Jwt::LoginCreate.call(user:, device_session:).token
        end

        def start_device_session
          started = DeviceSessions::Start.call(user:, installation_id:, platform:, app_version:)
          context.fail!(application_error: started.errors.first) if started.failure?

          started.data[:device_session]
        end

        # Hook for the installation-id cookie (a later task). Intentionally a no-op for now.
        def install_installation_cookie(_device_session); end
      end
    end
  end
end
