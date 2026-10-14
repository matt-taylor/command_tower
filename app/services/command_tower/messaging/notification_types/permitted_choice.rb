# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      # A declared default plus the values a member may choose from. Used by the
      # `urgency` and `sound` declaration fields. `allowed` is either an Array of ids or
      # the String "all" (every value in the universe). The mode is derived from
      # `allowed`, never stored:
      #
      #   fixed       one permitted value
      #   restricted  an explicit list of more than one
      #   full        "all"
      PermittedChoice = Data.define(:default, :allowed) do
        # Normalizes a declaration input. `nil` becomes a choice fixed on `fallback_default`.
        # A Hash is coerced. Any other value is returned unchanged so the validator can
        # report it (mirrors how `default_preference_state` is handled).
        def self.from(raw, fallback_default:)
          return new(default: fallback_default, allowed: [fallback_default].freeze) if raw.nil?
          return raw unless raw.is_a?(Hash)

          hash = raw.transform_keys(&:to_sym)
          default = hash[:default]&.to_s
          allowed = hash[:allowed]
          allowed =
            if allowed.nil?
              default.nil? ? nil : [default].freeze
            elsif allowed.is_a?(Array)
              allowed.map(&:to_s).freeze
            elsif allowed.to_s == "all"
              "all"
            else
              allowed
            end

          new(default:, allowed:)
        end

        def mode
          return :full if allowed == "all"

          allowed.size > 1 ? :restricted : :fixed
        end

        def permitted(universe)
          allowed == "all" ? universe.to_a : allowed
        end

        def selectable?(universe)
          permitted(universe).size > 1
        end
      end
    end
  end
end
