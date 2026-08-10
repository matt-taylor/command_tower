# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      module ReasonClasses
        SUPPRESSED_BY_PREFERENCE = "suppressed_by_preference"
        SKIPPED_BY_POLICY = "skipped_by_policy"

        ALL = [
          SUPPRESSED_BY_PREFERENCE,
          SKIPPED_BY_POLICY,
        ].freeze
      end
    end
  end
end
