# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module ExperienceStates
        class List < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            host_key = CommandTower.config.application.host_key.to_s
            if host_key.blank?
              context.fail!(
                application_error: CommandTower::Errors::Account::ExperienceStatesHostUnconfiguredError.new,
              )
              return
            end

            context.experience_states = CommandTower::UserExperienceState.for_user_and_host(
              user:,
              host_key:,
            ).order(:completed_at, :id).to_a
          end
        end
      end
    end
  end
end
