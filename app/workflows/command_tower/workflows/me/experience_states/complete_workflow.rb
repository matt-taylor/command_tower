# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module ExperienceStates
        class CompleteWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, experience_key:, scope_type:, scope_identifier:, version:, auth_context: nil)
            # Check order matters: impersonation, then the rate limit (so unregistered traffic is
            # throttled), then the registry, then the cap (inside Complete, only when no row exists).
            errors = precondition_errors(current_user, experience_key, scope_type)
            return rejected(*errors) if errors

            result = CommandTower::Services::Account::ExperienceStates::Complete.call(
              user: current_user,
              experience_key:,
              scope_type:,
              scope_identifier:,
              version:,
            )
            return rejected(*result.errors) unless result.success?

            if result.data[:created]
              audit(
                :experience_state_completed,
                affected_user: current_user,
                changes: {},
                metadata: { experience_key:, version: },
                scope_class: :host,
                host_context: {
                  type: scope_type,
                  identifier: scope_identifier,
                },
              )
            end

            success(
              payload: WorkflowSupport.serialize_view(result.data[:experience_state]),
              http_status: :ok,
              response_effects: WorkflowSupport.expire_header_effects(auth_context),
            )
          end

          private

          # Returns the errors of the first failing precondition, or nil when all pass.
          def precondition_errors(user, experience_key, scope_type)
            if CommandTower::Current.impersonation_active
              return [CommandTower::Errors::Account::ExperienceStateImpersonationForbidden.new]
            end

            limited = CommandTower::Services::Account::ExperienceStates::CheckCompleteRateLimit.call(user:)
            return limited.errors unless limited.success?

            return if registered?(experience_key, scope_type)

            [CommandTower::Errors::Account::ExperienceStateUnregistered.new]
          end

          def registered?(experience_key, scope_type)
            registry = CommandTower.config.registry.experience_states
            registry.registered?(experience_key) && registry.fetch(experience_key).scope_type?(scope_type)
          end

          def rejected(*errors)
            failure(
              errors:,
              http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(errors.first),
            )
          end
        end
      end
    end
  end
end
