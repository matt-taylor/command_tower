# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module ExperienceStates
        # Read-only check for whether one completion fact exists for the user. The host_key is
        # server-bound; callers never supply it.
        class Completed < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :experience_key, is_a: String, required: true
          validate :scope_type, is_a: String, required: true
          validate :scope_identifier, is_a: String, required: true
          validate :version, is_a: String, required: true

          def call
            host_key = CommandTower.config.application.host_key.to_s
            return fail_unconfigured if host_key.blank?

            context.completed = CommandTower::UserExperienceState.exists?(identity(host_key))
          end

          private

          def identity(host_key)
            { user:, host_key:, experience_key:, scope_type:, scope_identifier:, version: }
          end

          def fail_unconfigured
            context.fail!(application_error: CommandTower::Errors::Account::ExperienceStatesHostUnconfiguredError.new)
          end
        end
      end
    end
  end
end
