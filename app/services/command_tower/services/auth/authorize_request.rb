# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class AuthorizeRequest < CommandTower::Services::ApplicationService
        validate :current_user, is_a: User, required: true
        validate :controller_class, is_a: Class, required: true
        validate :action_name, is_a: String, required: true

        def call
          result = CommandTower::Authorize::Validate.call(
            user: current_user,
            controller: controller_class,
            method: action_name
          )

          context.authorization_required = result.authorization_required

          if result.failure?
            context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
            return
          end

          # Fail closed: an action the host never mapped into RBAC is not
          # implicitly public once it sits behind the authorization boundary.
          unless result.authorization_required
            context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
          end
        end
      end
    end
  end
end
