# frozen_string_literal: true

module CommandTower
  module Serializers
    module HomeNotices
      # The payload of a kill-switch update: `{ key, enabled }`.
      class ControlSerializer
        def self.serialize(key:, enabled:)
          { key: key.to_s, enabled: enabled == true }
        end
      end
    end
  end
end
