# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class LogoutWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(token: nil)
          maybe_audit_session_cleared(token)
          success(
            payload: CommandTower::Serializers::Auth::LogoutResponseSerializer.serialize,
            http_status: :ok,
            response_effects: { clear_token: true }
          )
        end

        private

        def maybe_audit_session_cleared(token)
          return if token.to_s.strip.empty?

          outcome = CommandTower::Jwt::AuthenticateUser.(token:, bypass_email_validation: true)
          return unless outcome.success?

          end_overlay_session(outcome)
          audit(:session_cleared, affected_user: outcome.user, changes: {})
        end

        def end_overlay_session(outcome)
          session_id = outcome.impersonation_session_id.to_s.strip
          return if session_id.empty?

          ended = CommandTower::Services::Impersonation::End.call(
            session_id:,
            reason: "logout",
            actor_user_id: outcome.user.id
          )
          return unless ended.success? && ended.data[:ended]

          session = ended.data[:session]
          target = User.find_by(id: session.target_user_id)
          return if target.nil?

          CommandTower::Impersonation::ClearOverlayForAudit.call(actor_user_id: outcome.user.id) do
            audit(
              :impersonation_ended,
              subject: target,
              affected_user: target,
              changes: { reason: { from: nil, to: "logout" } },
              metadata: { impersonation_session_id: session.id },
              attribution_mode: :admin_direct
            )
          end
        end
      end
    end
  end
end
