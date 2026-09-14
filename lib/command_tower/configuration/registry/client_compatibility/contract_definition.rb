# frozen_string_literal: true

module CommandTower
  module Configuration
    module Registry
      module ClientCompatibility
        # A named client contract: a CT-owned or host-owned identity that
        # per-platform host-app versions are bound to. Authority §7. V1 ships
        # with an empty CT-owned catalog by design — no placeholder contracts.
        class ContractDefinition
          attr_accessor :owner, :id
        end
      end
    end
  end
end
