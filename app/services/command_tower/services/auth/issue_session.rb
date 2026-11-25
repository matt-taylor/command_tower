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
          context.installation_id = effective_installation_id
          context.device_session = start_device_session
          issue_token
          context.set_installation_cookie = installation_cookie_needed?
        end

        private

        def issue_token
          context.token = mint_token(context.device_session)
          context.expires_at = token_expires_at
        end

        # An explicit id wins, then the one the HTTP boundary read from the request. A cookie-mode
        # (web) login with neither gets a fresh id so the response can plant the cookie.
        def effective_installation_id
          explicit = installation_id.presence || CommandTower::Current.installation_id
          return explicit if explicit.present?

          SecureRandom.uuid if CommandTower::Jwt::AuthorizationHelper.cookie_enabled?
        end

        # The cookie is planted for web logins (cookie mode) unless the client already sent the
        # id in the header, as native clients do.
        def installation_cookie_needed?
          CommandTower::Jwt::AuthorizationHelper.cookie_enabled? &&
            context.installation_id.present? &&
            CommandTower::Current.installation_id_source != :header
        end

        def token_expires_at
          CommandTower.config.jwt.ttl.from_now.to_time.to_s
        end

        def mint_token(device_session)
          CommandTower::Jwt::LoginCreate.call(user:, device_session:).token
        end

        def start_device_session
          started = DeviceSessions::Start.call(user:, installation_id: context.installation_id, platform:, app_version:)
          context.fail!(application_error: started.errors.first) if started.failure?

          started.data[:device_session]
        end
      end
    end
  end
end
