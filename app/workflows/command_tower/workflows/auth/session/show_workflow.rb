# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module Session
        class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
          include CommandTower::Workflows::ClientCompatibility::RecommendationMeta

          retry_strategy :none

          def call(current_user:, auth_context:)
            upgraded = upgrade_legacy_token(auth_context)
            auth_context = upgraded if upgraded

            response_effects = {
              set_expire_header: auth_context.token_expires_at
            }

            if auth_context.generated_token.present?
              response_effects[:set_token] = token_effect(auth_context)
              response_effects[:ensure_csrf_cookie] = { rotate: upgraded ? false : csrf_rotate_on_reset? }
            end

            impersonation_session = impersonation_session_for(auth_context)

            success(
              payload: CommandTower::Serializers::Auth::SessionResponseSerializer.serialize(
                user: current_user,
                token_expires_at: auth_context.token_expires_at,
                impersonation_session:,
                actor: auth_context.actor_user
              ),
              http_status: :ok,
              meta: client_compatibility_meta,
              response_effects: response_effects
            )
          end

          private

          # A sid-less legacy token gets a device session and a replacement token that carries
          # its sid. This wins over a plain refresh (X-Authorization-Reset), and the CSRF
          # cookie is only ensured, never rotated. Returns the context with the new token, or nil.
          def upgrade_legacy_token(auth_context)
            return unless upgrade_legacy?(auth_context)

            upgraded = CommandTower::Services::Auth::DeviceSessions::UpgradeLegacy.call(
              user: auth_context.actor_user,
              legacy_generated_at: auth_context.legacy_generated_at.to_i,
              installation_id: CommandTower::Current.installation_id
            )
            return if upgraded.failure?

            device_session = upgraded.data[:device_session]
            token = CommandTower::Jwt::LoginCreate.call(
              user: auth_context.actor_user,
              impersonation_session_id: auth_context.impersonation_session_id,
              device_session:
            ).token

            auth_context.with(
              device_session:,
              legacy_token: false,
              generated_token: token,
              token_expires_at: session_expires_at(device_session).to_s
            )
          end

          def upgrade_legacy?(auth_context)
            auth_context.legacy_token &&
              auth_context.legacy_generated_at.present? &&
              CommandTower.config.session.upgrade_legacy_tokens
          end

          def session_expires_at(device_session)
            idle_expires_at = device_session.last_seen_at + CommandTower.config.session.idle_timeout
            [idle_expires_at, device_session.absolute_expires_at].min.to_time
          end

          def token_effect(auth_context)
            CommandTower::Workflows::Auth::AuthenticationResponseEffects.for_set_token(
              token: auth_context.generated_token,
              expires_at: auth_context.token_expires_at,
              device_session: auth_context.device_session,
              # Cookie-sourced refresh rides the cookie only; bearer clients read the header.
              header: auth_context.token_source != :cookie
            )
          end

          def csrf_rotate_on_reset?
            return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?

            CommandTower.config.jwt.cookie.csrf.rotate_on_reset
          end

          def impersonation_session_for(auth_context)
            return unless CommandTower::Current.impersonation_active

            session_id = auth_context.impersonation_session_id.presence ||
              CommandTower::Current.impersonation_session_id
            return if session_id.blank?

            CommandTower::Impersonation::Session.find_by(id: session_id)
          end
        end
      end
    end
  end
end
