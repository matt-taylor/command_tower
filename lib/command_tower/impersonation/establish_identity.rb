# frozen_string_literal: true

module CommandTower
  module Impersonation
    EstablishedIdentity = Data.define(:user, :actor, :session, :status) do
      def expired?
        status == :expired
      end

      def active?
        status == :active
      end
    end

    module EstablishIdentity
      module_function

      def call(actor:, impersonation_session_id:, mode: :enforce)
        overlay = ApplyOverlay.call(actor:, session_id: impersonation_session_id, mode:)
        if overlay.status == :expired && mode.to_sym == :enforce
          CommandTower::Execution::IdentityEnrichment.from_user(actor)
          return EstablishedIdentity.new(user: actor, actor:, session: overlay.session, status: :expired)
        end

        if overlay.status == :active
          CommandTower::Execution::IdentityEnrichment.from_impersonation_session(
            overlay.session,
            actor: overlay.actor,
            target: overlay.target
          )
          return EstablishedIdentity.new(
            user: overlay.target,
            actor: overlay.actor,
            session: overlay.session,
            status: :active
          )
        end

        CommandTower::Execution::IdentityEnrichment.from_user(actor)
        EstablishedIdentity.new(user: actor, actor:, session: overlay.session, status: overlay.status)
      end
    end
  end
end
