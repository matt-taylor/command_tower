# frozen_string_literal: true

module CommandTower
  module Auth
    # Transport hook for deprecated auth endpoints. `deprecated_auth_endpoint "name"` records
    # one `auth.legacy_contract_used` event per request, before authentication runs, so
    # rejected calls from old clients still count. Observation only.
    module LegacyContractBoundary
      extend ActiveSupport::Concern

      class_methods do
        def deprecated_auth_endpoint(endpoint, **)
          before_action(**) { record_legacy_contract_use(endpoint) }
        end
      end

      private

      def record_legacy_contract_use(endpoint)
        CommandTower::Services::Auth::RecordLegacyContractUse.call(endpoint: endpoint)
      end
    end
  end
end
