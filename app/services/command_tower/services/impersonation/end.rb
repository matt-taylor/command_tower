# frozen_string_literal: true

module CommandTower
  module Services
    module Impersonation
      class End < CommandTower::Services::ApplicationService
        validate :session_id, is_a: String, required: true
        validate :reason, is_a: String, required: true
        validate :actor_user_id, is_a: Integer, required: false

        def call
          unless CommandTower::Impersonation::Session::END_REASONS.include?(reason)
            return context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end

          now = Time.current
          relation = CommandTower::Impersonation::Session.open.where(id: session_id)
          relation = relation.where(actor_user_id:) if actor_user_id
          updated = relation.update_all(ended_at: now, end_reason: reason, updated_at: now)

          session = CommandTower::Impersonation::Session.find_by(id: session_id)
          context.session = session
          context.ended = updated.positive?
        end
      end
    end
  end
end
