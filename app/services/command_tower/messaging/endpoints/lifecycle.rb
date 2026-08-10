# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Lifecycle
        module_function

        TRANSITIONS = {
          "active" => %w[revoked invalid retired].freeze,
          "revoked" => %w[retired].freeze,
          "invalid" => %w[retired].freeze,
          "retired" => [].freeze,
        }.freeze

        def assert_transition!(from:, to:)
          allowed = TRANSITIONS.fetch(from.to_s) { [] }
          return if allowed.include?(to.to_s)

          raise InvalidTransitionError,
                "illegal lifecycle transition: #{from.inspect} → #{to.inspect}"
        end

        def apply!(record, to:, revoked_at: nil)
          from = record.lifecycle_state
          assert_transition!(from:, to:)
          record.lifecycle_state = to.to_s
          if to.to_s == "revoked"
            record.revoked_at = revoked_at || Time.current
          end
          record.derive_uniqueness_columns!
          record
        end
      end
    end
  end
end
