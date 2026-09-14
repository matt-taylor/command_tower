# frozen_string_literal: true

module CommandTower
  module Errors
    # Hard client-version incompatibility (authority §14). Deliberately NOT
    # registered in `SessionErrorStatus` — its HTTP status (426) is set
    # directly by `Workflows::ClientCompatibility::EvaluateWorkflow`, not
    # derived from that closed 401/403/412 mapping table.
    class ClientUpdateRequiredError < ApplicationError
      def initialize(details: {})
        super(details:)
      end

      def code
        "client_update_required"
      end

      def message
        "Client update required"
      end

      def log_level
        :warn
      end
    end
  end
end
