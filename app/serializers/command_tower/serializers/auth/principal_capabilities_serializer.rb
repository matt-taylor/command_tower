# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class PrincipalCapabilitiesSerializer
        def self.serialize(principal_capability_ids)
          {
            principalCapabilities: Array(principal_capability_ids).map(&:to_s)
          }
        end
      end
    end
  end
end
