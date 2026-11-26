# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # Response body and transport effects for a registration. With `start_session` the response
      # is login-shaped (token, tokenExpiresAt, cookies); without it, the legacy `{ user, message }`.
      module RegisterSessionResponse
        module_function

        def payload(user:, session:)
          serializer = CommandTower::Serializers::Auth::RegisterResponseSerializer
          return serializer.serialize(user:) if session.nil?

          serializer.serialize(
            user:,
            token: session[:token],
            token_expires_at: session[:expires_at],
            include_token: !CommandTower::Services::Auth::OmitBodyToken.call,
            capabilities: capabilities(user)
          )
        end

        # Lets the client show the username step right after signup (grace 0 unverified accounts included).
        def capabilities(user)
          { editUsername: { enabled: CommandTower::Services::Me::UsernameChangeEligibility.eligible?(user) } }
        end

        # Same transport effects as login: token header/cookie, CSRF cookie, installation cookie.
        def effects(session)
          return {} if session.nil?

          effects = { set_token: token_effect(session), ensure_csrf_cookie: { rotate: csrf_rotate_on_login? } }
          effects[:set_installation_cookie] = session[:installation_id] if session[:set_installation_cookie]
          effects
        end

        def token_effect(session)
          AuthenticationResponseEffects.for_set_token(
            token: session[:token],
            expires_at: session[:expires_at],
            device_session: session[:device_session]
          )
        end

        def csrf_rotate_on_login?
          return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?

          CommandTower.config.jwt.cookie.csrf.rotate_on_login
        end
      end
    end
  end
end
