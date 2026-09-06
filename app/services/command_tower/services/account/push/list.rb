# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Push
        class List < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            views = CommandTower::Messaging::Endpoints.list(
              owner_user_id: user.id,
              channel_key: "push",
            )
            context.safe_views = views.select { |view| view.lifecycle_state.to_s == "active" }
          rescue CommandTower::Messaging::Endpoints::Error => e
            context.fail!(application_error: CtSupport.map_ct_exception!(e))
          end
        end
      end
    end
  end
end
