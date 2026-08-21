# frozen_string_literal: true

module CommandTower
  module Workflows
    module Impersonation
      class StopWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(actor:, impersonation_session_id:, token_expires_at: nil)
          session_id = impersonation_session_id.to_s.strip
          if session_id.empty?
            return failure(
              errors: [CommandTower::Errors::Auth::ImpersonationSessionMissingError.new],
              http_status: :unprocessable_entity
            )
          end

          ended = CommandTower::Services::Impersonation::End.call(
            session_id:,
            reason: "manual",
            actor_user_id: actor.id
          )
          unless ended.success?
            return failure(
              errors: ended.errors,
              http_status: CommandTower::Workflows::Impersonation::ErrorMapping.http_status_for(ended.errors.first)
            )
          end

          session = ended.data[:session]
          if session.nil? || session.actor_user_id != actor.id
            return failure(
              errors: [CommandTower::Errors::Auth::ImpersonationSessionMissingError.new],
              http_status: :unprocessable_entity
            )
          end

          if ended.data[:ended]
            target = User.find_by(id: session.target_user_id)
            if target
              audit(
                :impersonation_ended,
                subject: target,
                affected_user: target,
                changes: { reason: { from: nil, to: "manual" } },
                metadata: { impersonation_session_id: session.id },
                attribution_mode: CommandTower::Current.impersonation_active ? nil : :admin_direct
              )
            end
          end

          token = CommandTower::Jwt::LoginCreate.call(user: actor).token
          expires_at = token_expires_at.presence || CommandTower.config.jwt.ttl.from_now.to_time.to_s

          success(
            payload: { message: "impersonation_ended" },
            http_status: :ok,
            response_effects: {
              set_token: { token:, expires_at: }
            }
          )
        end
      end
    end
  end
end
