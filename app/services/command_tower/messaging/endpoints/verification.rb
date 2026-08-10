# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Verification
        module_function

        TRANSITIONS = {
          "unverified" => %w[pending verified failed].freeze,
          "pending" => %w[verified failed unverified].freeze,
          "verified" => %w[unverified failed].freeze,
          "failed" => %w[pending unverified].freeze,
        }.freeze

        def assert_transition!(from:, to:)
          allowed = TRANSITIONS.fetch(from.to_s) { [] }
          return if allowed.include?(to.to_s)

          raise InvalidTransitionError,
                "illegal verification transition: #{from.inspect} → #{to.inspect}"
        end

        def apply!(record, to:)
          from = record.verification_state
          assert_transition!(from:, to:)
          record.verification_state = to.to_s
          case to.to_s
          when "verified"
            record.verified_at = Time.current
          when "unverified"
            record.verified_at = nil
          end
          record
        end
      end
    end
  end
end
