# frozen_string_literal: true

module CommandTower
  module Services
    module Impersonation
      class TerminateOpenSessions < CommandTower::Services::ApplicationService
        validate :actor_user_id, is_a: Integer, required: true
        validate :reason, is_a: String, required: true

        def call
          unless CommandTower::Impersonation::Session::END_REASONS.include?(reason)
            return context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end

          ids = CommandTower::Impersonation::Session.open.where(actor_user_id:).pluck(:id)
          ended_count = 0
          ids.each do |session_id|
            ended = CommandTower::Services::Impersonation::End.call(
              session_id:,
              reason:,
              actor_user_id:
            )
            next unless ended.success? && ended.data[:ended]

            ended_count += 1
            emit_ended(ended.data[:session], reason:)
          end
          context.ended_count = ended_count
        end

        private

        def emit_ended(session, reason:)
          target = User.find_by(id: session.target_user_id)
          return if target.nil?

          CommandTower::Impersonation::ClearOverlayForAudit.call(actor_user_id:) do
            audit(
              :impersonation_ended,
              subject: target,
              affected_user: target,
              changes: { reason: { from: nil, to: reason } },
              metadata: { impersonation_session_id: session.id },
              attribution_mode: :admin_direct
            )
          end
        end
      end
    end
  end
end
