# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module ClientCompatibility
        # Host-owned platform-global policy for one canonical platform
        # (`web`, `ios`, or `android`). Authority §5.
        class PlatformDefinition
          include ClassComposer::Generator

          add_composer :minimum,
            desc: "Platform-global minimum supported app version (MAJOR.MINOR.PATCH[.prerelease])",
            allowed: [String, NilClass],
            default: nil

          add_composer :recommended,
            desc: "Platform-global recommended app version, surfaced as non-blocking guidance",
            allowed: [String, NilClass],
            default: nil

          add_composer :update_url,
            desc: "Store/update destination surfaced on hard-incompatibility recovery (native platforms only)",
            allowed: [String, NilClass],
            default: nil

          attr_reader :platform

          def validate_definition!(platform:)
            @platform = platform.to_sym
            self.minimum = require_version!(minimum, field: "minimum")

            if recommended.present?
              self.recommended = require_version!(recommended, field: "recommended")
              if Gem::Version.new(recommended) < Gem::Version.new(minimum)
                raise CommandTower::ClientCompatibility::ConflictingRequirementError,
                  "platform #{@platform} recommended #{recommended} is lower than minimum #{minimum}"
              end
            end

            if @platform == :web && update_url.present?
              raise CommandTower::ClientCompatibility::InvalidPlatformError,
                "platform web MUST NOT configure update_url (web recovery is reload, not an app store)"
            end

            self
          end

          private

          def require_version!(value, field:)
            normalized = CommandTower::ClientCompatibility::Version.normalize(value)
            if normalized.nil?
              raise CommandTower::ClientCompatibility::InvalidVersionError,
                "platform #{@platform} has invalid #{field} #{value.inspect}"
            end

            normalized
          end
        end
      end
    end
  end
end
