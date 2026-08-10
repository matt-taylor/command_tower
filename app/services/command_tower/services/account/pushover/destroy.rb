# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Pushover
        class Destroy < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            active = CtSupport.active_endpoint(user)
            if active.nil?
              context.fail!(application_error: CommandTower::Errors::Account::PushoverNotConfiguredError.new)
              return
            end

            begin
              context.safe_view = CommandTower::Messaging::Endpoints.revoke(
                owner_user_id: user.id,
                endpoint_id: active.id
              )
            rescue CommandTower::Messaging::Endpoints::Error => e
              context.fail!(application_error: CtSupport.map_ct_exception!(e))
            end
          end
        end
      end
    end
  end
end
