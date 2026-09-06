# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Push
        class Destroy < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :endpoint_id, required: true

          def call
            context.safe_view = CommandTower::Messaging::Endpoints.revoke(
              owner_user_id: user.id,
              endpoint_id:,
            )
          rescue CommandTower::Messaging::Endpoints::Error => e
            context.fail!(application_error: CtSupport.map_ct_exception!(e))
          end
        end
      end
    end
  end
end
