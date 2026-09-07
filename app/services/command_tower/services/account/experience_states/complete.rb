# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module ExperienceStates
        class Complete < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :experience_key, is_a: String, required: true
          validate :scope_type, is_a: String, required: true
          validate :scope_identifier, is_a: String, required: true
          validate :version, is_a: String, required: true

          def call
            host_key = CommandTower.config.application.host_key.to_s
            if host_key.blank?
              context.fail!(
                application_error: CommandTower::Errors::Account::ExperienceStatesHostUnconfiguredError.new,
              )
              return
            end

            identity = {
              user:,
              host_key:,
              experience_key:,
              scope_type:,
              scope_identifier:,
              version:,
            }

            existing = CommandTower::UserExperienceState.find_by(identity)
            if existing
              context.experience_state = existing
              context.created = false
              return
            end

            begin
              created = CommandTower::UserExperienceState.create!(
                identity.merge(completed_at: Time.current),
              )
              context.experience_state = created
              context.created = true
            rescue ActiveRecord::RecordNotUnique
              recovered = CommandTower::UserExperienceState.find_by!(identity)
              context.experience_state = recovered
              context.created = false
            end
          end
        end
      end
    end
  end
end
