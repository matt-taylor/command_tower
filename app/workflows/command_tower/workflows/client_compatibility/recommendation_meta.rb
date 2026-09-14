# frozen_string_literal: true

module CommandTower
  module Workflows
    module ClientCompatibility
      # Shared sequence fragment: reads the recommendation projection that
      # `EvaluateWorkflow` stashed on `Current` (never written by `Evaluate`
      # itself) and shapes it into `WorkflowResult.meta`. Included only by
      # Login and Session::Show — recommended-update guidance is deliberately
      # not attached to every success envelope (authority §13).
      module RecommendationMeta
        extend ActiveSupport::Concern

        private

        def client_compatibility_meta
          recommendation = CommandTower::Current.client_compatibility_recommendation
          return {} if recommendation.blank?

          { clientCompatibility: recommendation }
        end
      end
    end
  end
end
