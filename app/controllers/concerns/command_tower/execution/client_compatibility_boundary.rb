# frozen_string_literal: true

module CommandTower
  module Execution
    # Runs the client-version-compatibility check for every JSON request,
    # before any authentication/authorization filter. Transport-only: it
    # invokes exactly one workflow and renders its result — all decisioning
    # lives in `Workflows::ClientCompatibility::EvaluateWorkflow` /
    # `Services::ClientCompatibility::Evaluate` (authority §10).
    #
    # Hosts that need to exempt a controller (e.g. a healthz-style endpoint)
    # do so with `skip_before_action :evaluate_client_compatibility!`.
    module ClientCompatibilityBoundary
      extend ActiveSupport::Concern

      included do
        include CommandTower::Api::ApplicationResponseRenderer
        before_action :evaluate_client_compatibility!
      end

      private

      def evaluate_client_compatibility!
        result = CommandTower::Workflows::ClientCompatibility::EvaluateWorkflow.call(
          request: request,
          controller_class: self.class,
          action_name: action_name
        )

        unless result.success?
          render_application_result(result)
          return false
        end

        true
      end
    end
  end
end
