# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Push
        class Replace < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :endpoint_id, required: true
          validate :address, is_a: String, required: true

          def call
            view = CommandTower::Messaging::Endpoints.replace(
              owner_user_id: user.id,
              endpoint_id:,
              address:,
            )
            context.safe_view = CtSupport.ensure_verified!(owner_user_id: user.id, safe_view: view)
          rescue CommandTower::Messaging::Endpoints::Error => e
            context.fail!(application_error: CtSupport.map_ct_exception!(e))
          end
        end
      end
    end
  end
end
