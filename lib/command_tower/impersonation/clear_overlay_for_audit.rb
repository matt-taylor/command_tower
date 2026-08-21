# frozen_string_literal: true

module CommandTower
  module Impersonation
    # Temporarily clear overlay identity so impersonation_ended audits attribute
    # as admin_direct to the actor. Lives outside workflows/services so leaf
    # layers do not establish Current execution boundaries themselves.
    module ClearOverlayForAudit
      module_function

      def call(actor_user_id:)
        CommandTower::Current.set(
          user_id: actor_user_id,
          effective_user_id: actor_user_id,
          originating_administrator_id: nil,
          impersonation_active: false
        ) do
          yield
        end
      end
    end
  end
end
