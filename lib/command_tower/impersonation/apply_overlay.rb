# frozen_string_literal: true

module CommandTower
  module Impersonation
    Overlay = Data.define(:actor, :target, :session, :status)

    module ApplyOverlay
      module_function

      def call(actor:, session_id:, mode: :enforce)
        token = session_id.to_s.strip
        return Overlay.new(actor:, target: actor, session: nil, status: :none) if token.empty?

        session = CommandTower::Impersonation::Session.find_by(id: token)
        if session.nil? || session.actor_user_id != actor.id
          return reject_or_none(actor:, session: nil, mode:)
        end

        unless session.open?
          return reject_or_none(actor:, session:, mode:)
        end

        if session.expired?
          return expire_open_session(actor:, session:, mode:)
        end

        target = User.find_by(id: session.target_user_id)
        if target.nil?
          ended = end_session(session, reason: "revoked", actor:)
          emit_ended(ended, reason: "revoked") if ended
          return reject_or_none(actor:, session: session.reload, mode:)
        end

        Overlay.new(actor:, target:, session:, status: :active)
      end

      def reject_or_none(actor:, session:, mode:)
        if mode.to_sym == :enforce
          return Overlay.new(actor:, target: actor, session:, status: :expired)
        end

        Overlay.new(actor:, target: actor, session:, status: :none)
      end
      private_class_method :reject_or_none

      def expire_open_session(actor:, session:, mode:)
        reason = session.expiration_reason
        if mode.to_sym == :enforce
          ended = end_session(session, reason:, actor:)
          emit_ended(ended, reason:) if ended
          return Overlay.new(actor:, target: actor, session: session.reload, status: :expired)
        end

        Overlay.new(actor:, target: actor, session:, status: :stale)
      end
      private_class_method :expire_open_session

      def end_session(session, reason:, actor:)
        result = CommandTower::Services::Impersonation::End.call(
          session_id: session.id,
          reason:,
          actor_user_id: actor.id
        )
        return unless result.success? && result.data[:ended]

        result.data[:session]
      end
      private_class_method :end_session

      def emit_ended(session, reason:)
        target = User.find_by(id: session.target_user_id)
        return if target.nil?

        CommandTower::Current.user_id = session.actor_user_id
        CommandTower::Current.effective_user_id = session.actor_user_id
        CommandTower::Current.originating_administrator_id = nil
        CommandTower::Current.impersonation_active = false

        CommandTower::Audit::Emit.call(
          name: :impersonation_ended,
          subject: target,
          affected_user: target,
          changes: { reason: { from: nil, to: reason } },
          metadata: { impersonation_session_id: session.id },
          attribution_mode: :admin_direct
        )
      end
      private_class_method :emit_ended
    end
  end
end
