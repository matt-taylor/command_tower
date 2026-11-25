# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module HomeNotices
        # `PATCH /admin/home-notices/:key`: switches one registered notice key on or off (the kill
        # switch the delivery read path honours).
        #
        # Authorization and the impersonation refusal belong to the controller. An unregistered key is
        # a 404 and writes nothing. The write and its audit share one transaction: the audit
        # `home_notice_control_changed` (admin attribution, `changes: { enabled: { from, to } }`,
        # metadata `key`) is emitted only when this request changed the effective state; setting a
        # key to the state it already has is an idempotent success with no audit. A database failure
        # is 503 `home_notices_unavailable`.
        #
        # Success payload is `{ key:, enabled: }`.
        class UpdateControlWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:, key:, enabled:)
            return not_found unless CommandTower::HomeNotices::Catalog.registered?(key)

            transaction do
              updated = CommandTower::Services::HomeNotices::UpdateControl.call(
                key:, enabled:, updated_by_user_id: user.id
              )
              fail_transaction!(unavailable) if updated.failure?

              audit_change(key:, data: updated.data) if updated.data[:changed]
              success(payload: control_payload(key:, enabled: updated.data[:enabled]), http_status: :ok)
            end
          end

          private

          def control_payload(key:, enabled:)
            CommandTower::Serializers::HomeNotices::ControlSerializer.serialize(key:, enabled:)
          end

          def audit_change(key:, data:)
            audit(
              :home_notice_control_changed,
              changes: { enabled: { from: data[:previous_enabled], to: data[:enabled] } },
              metadata: { key: },
              attribution_mode: :admin_direct
            )
          end

          def not_found
            failure(errors: [CommandTower::Errors::NotFoundError.new], http_status: :not_found)
          end

          def unavailable
            failure(
              errors: [CommandTower::Errors::HomeNotices::UnavailableError.new],
              http_status: :service_unavailable
            )
          end
        end
      end
    end
  end
end
