# frozen_string_literal: true

module ApiEngineBase::Authorize
  class Validate < ApiEngineBase::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true
    validate :controller, is_a: [ActionController::Base, ActionController::API], required: true
    validate :method, is_a: String, required: true

    def call
      context.authorization_required = authorization_required?
      unless context.authorization_required
        log_info("controller:#{controller}; method:#{method} -- No Authorization required")
        context.msg = "Authorization not required at this time"
        return
      end

      # At this point we know authorization on the route is required
      # Iterate through the users roles to find a matching role that allows authorization
      # If at least 1 of the users roles passes validation, we can allow access to the path
      log_info("User Roles: #{user.roles}")
      auhorization_result = user_role_objects.any? do |_role_name, role_object|
        result = role_object.authorized?(controller:, method:, user:)
        log_info("Role:#{result[:role]};Authorized:[#{result[:authorized]}];Reason:[#{result[:reason]}]")
        result[:authorized] == true
      end

      if auhorization_result
        context.msg = "User is Authorized for action"
      else
        context.fail!(msg: "Unauthorized Access. Incorrect User Privileges")
      end
    end

    def authorization_required?
      controller_mapping = ApiEngineBase::Authorization.mapped_controllers[controller]
      return false if controller_mapping.nil?

      controller_mapping.include?(method.to_sym)
    end

    def user_role_objects
      ApiEngineBase::Authorization::Role.roles.select do |role_name, _|
        user.roles.include?(role_name.to_s)
      end
    end
  end
end
