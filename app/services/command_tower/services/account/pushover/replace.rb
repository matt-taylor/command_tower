# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Pushover
        class Replace < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :user_key, is_a: String, required: true
          validate :application_token, is_a: String, required: true

          def call
            context.safe_view = CommandTower::Messaging::Endpoints.replace(
              owner_user_id: user.id,
              channel_key: "pushover",
              credentials: {
                user_key:,
                application_token:
              }
            )
          rescue CommandTower::Messaging::Endpoints::Error => e
            context.fail!(application_error: CtSupport.map_ct_exception!(e))
          end
        end
      end
    end
  end
end
