# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class AssignDefaultMembershipRole < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true

        def call
          role_name = CommandTower.config.authorization.default_membership_role
          if role_name.nil?
            context.user = user
            return
          end

          unless role_present?(role_name)
            context.fail!(
              application_error: CommandTower::Errors::Auth::DefaultMembershipAssignmentError.new(
                details: { role: role_name }
              )
            )
          end

          user.roles = (Array(user.roles) + [role_name.to_s]).uniq
          unless user.save
            context.fail!(
              application_error: CommandTower::Errors::Auth::DefaultMembershipAssignmentError.new(
                details: user.errors.to_hash
              )
            )
          end

          context.user = user
        end

        private

        def role_present?(role_name)
          role_name.to_s.strip.present? && CommandTower::Authorization::Role.roles[role_name].present?
        end
      end
    end
  end
end
