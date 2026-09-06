# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Push
        # Shared CT Endpoints helpers for Account push capability services.
        module CtSupport
          module_function

          def ensure_verified!(owner_user_id:, safe_view:)
            return safe_view if safe_view.verification_state.to_s == "verified"

            CommandTower::Messaging::Endpoints.mark_verified(
              owner_user_id:,
              endpoint_id: safe_view.id,
            )
          end

          def map_ct_exception!(error)
            case error
            when CommandTower::Messaging::Endpoints::NotFoundError
              CommandTower::Errors::Account::PushEndpointNotFoundError.new
            when CommandTower::Messaging::Endpoints::ValidationError
              if error.message.to_s.include?("disabled")
                CommandTower::Errors::Account::PushCapabilityUnavailableError.new
              else
                CommandTower::Errors::ValidationError.new(details: { base: "Invalid push token" })
              end
            else
              CommandTower::Errors::InternalError.new
            end
          end
        end
      end
    end
  end
end
