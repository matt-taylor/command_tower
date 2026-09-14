# frozen_string_literal: true

module CommandTower
  module Workflows
    module ClientCompatibility
      # Orchestrates one HTTP request's client-version-compatibility check.
      # Maps the pure `Services::ClientCompatibility::Evaluate` projection to
      # a `WorkflowResult`, and is the only layer (along with the boundary)
      # allowed to place recommendation metadata onto `CommandTower::Current`
      # — `Evaluate` itself never touches `Current` (authority §10, §13).
      class EvaluateWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        APP_VERSION_HEADER = "X-App-Version"
        PLATFORM_HEADER = "X-Client-Platform"

        def call(request:, controller_class:, action_name:)
          decision = CommandTower::Services::ClientCompatibility::Evaluate.call(
            app_version_header: request.headers[APP_VERSION_HEADER],
            platform_header: request.headers[PLATFORM_HEADER],
            controller_class: controller_class,
            action_name: action_name
          )

          mode = CommandTower.config.registry.client_compatibility.mode
          enforced = mode == :enforce
          blocked = enforced && decision.incompatible?

          log_decision(decision, mode:, enforced:, blocked:)
          stash_recommendation!(decision)

          if blocked
            return failure(
              errors: [CommandTower::Errors::ClientUpdateRequiredError.new(details: details_for(decision))],
              http_status: :upgrade_required
            )
          end

          success(payload: { decision: decision })
        end

        private

        def stash_recommendation!(decision)
          return unless decision.recommendation_projection

          CommandTower::Current.client_compatibility_recommendation = decision.recommendation_projection
        end

        def details_for(decision)
          {
            platform: decision.platform&.to_s,
            scope: decision.scope&.to_s,
            currentVersion: decision.current_version,
            minimumVersion: decision.effective_minimum,
            recovery: decision.recovery&.to_s,
            updateUrl: decision.update_url
          }.compact
        end

        # Structured (non-audit) decision log via the semantic `command_tower.log.*`
        # event contract (authority §20). Workflows must not write lifecycle
        # observation directly to `Rails.logger` — `publish_event` routes
        # through `CommandTower::Logging::Subscriber` like every other
        # semantic log line.
        def log_decision(decision, mode:, enforced:, blocked:)
          payload = {
            message: "client_compatibility.evaluated",
            mode: mode,
            enforced: enforced,
            platform: decision.platform,
            app_version: decision.current_version,
            matched_entities: decision.matched_entity_names,
            decision: decision.decision,
            http_status: blocked ? 426 : nil
          }.compact

          publish_event(category: :log, name: blocked ? :warn : :info, payload:)
        end
      end
    end
  end
end
