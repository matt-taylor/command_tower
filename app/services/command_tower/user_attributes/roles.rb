# frozen_string_literal: true

module CommandTower::UserAttributes
  class Roles < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true
    validate :admin_user, is_a: User, required: true
    validate :roles, is_a: Array, required: true

    def call
      if valid_roles?
        user.update!(roles:)
        return true
      end

      inline_argument_failure!(errors: { roles: "Invalid roles provided" })
    end

    def valid_roles?
      return true if roles.empty?

      available_roles = CommandTower::Authorization::Role.roles.keys
      roles.all? { available_roles.include?(_1) }
    end
  end
end
