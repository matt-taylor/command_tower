# frozen_string_literal: true

module CommandTower::Authorize
  # RBAC decision for a controller action. Shared by the engine's
  # `authorize_user!` transport filter and the modern AuthorizeRequest service,
  # so it stays a plain domain object with a narrow decision contract.
  class Validate
    include CommandTower::ServiceLogging

    NOT_REQUIRED_MSG = "Authorization not required at this time"
    AUTHORIZED_MSG = "User is Authorized for action"
    UNAUTHORIZED_MSG = "Unauthorized Access. Incorrect User Privileges"

    class Decision
      attr_reader :user, :authorization_required, :msg

      def self.authorized(user:, authorization_required:, msg:)
        new(success: true, user:, authorization_required:, msg:)
      end

      def self.denied(user:, msg:)
        new(success: false, user:, authorization_required: true, msg:)
      end

      def initialize(success:, user:, authorization_required:, msg:)
        @success = success
        @user = user
        @authorization_required = authorization_required
        @msg = msg
      end

      def success? = @success

      def failure? = !@success
    end

    def self.call(user:, controller:, method:)
      new(user:, controller:, method:).call
    end

    def initialize(user:, controller:, method:)
      @user = user
      @controller = controller
      @action = method
    end

    def call
      unless authorization_required?
        log_info("controller:#{controller}; method:#{action} -- No Authorization required")
        return Decision.authorized(user:, authorization_required: false, msg: NOT_REQUIRED_MSG)
      end

      # At this point we know authorization on the route is required
      # Iterate through the users roles to find a matching role that allows authorization
      # If at least 1 of the users roles passes validation, we can allow access to the path
      log_info("User Roles: #{user.roles}")
      authorized = user_role_objects.any? do |_role_name, role_object|
        result = role_object.authorized?(controller:, method: action, user:)
        log_info("Role:#{result[:role]};Authorized:[#{result[:authorized]}];Reason:[#{result[:reason]}]")
        result[:authorized] == true
      end

      return Decision.denied(user:, msg: UNAUTHORIZED_MSG) unless authorized

      Decision.authorized(user:, authorization_required: true, msg: AUTHORIZED_MSG)
    end

    private

    attr_reader :user, :controller, :action

    def authorization_required?
      controller_mapping = CommandTower::Authorization.mapped_controllers[controller]
      return false if controller_mapping.nil?

      controller_mapping.include?(action.to_sym)
    end

    def user_role_objects
      CommandTower::Authorization::Role.roles.select do |role_name, _|
        user.roles.include?(role_name.to_s)
      end
    end
  end
end
