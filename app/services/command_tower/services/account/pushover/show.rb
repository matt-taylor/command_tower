# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Pushover
        class Show < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            context.safe_view = CtSupport.active_endpoint(user)
          rescue CommandTower::Messaging::Endpoints::Error => e
            context.fail!(application_error: CtSupport.map_ct_exception!(e))
          end
        end
      end
    end
  end
end
