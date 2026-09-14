# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module ClientCompatibility
        # Direct per-platform minimum overrides on a host-owned entity requirement
        # (mutually exclusive with a `client_contract` reference). Authority §6.
        class MinimumOverrides
          include ClassComposer::Generator

          add_composer :web, desc: "Direct minimum for web", allowed: [String, NilClass], default: nil
          add_composer :ios, desc: "Direct minimum for ios", allowed: [String, NilClass], default: nil
          add_composer :android, desc: "Direct minimum for android", allowed: [String, NilClass], default: nil

          def any_set?
            [web, ios, android].any?(&:present?)
          end

          def for_platform(platform)
            public_send(platform)
          end

          def validate!(name:)
            %i[web ios android].each do |platform|
              value = public_send(platform)
              next if value.blank?

              normalized = CommandTower::ClientCompatibility::Version.normalize(value)
              if normalized.nil?
                raise CommandTower::ClientCompatibility::InvalidVersionError,
                  "entity requirement #{name} has invalid minimum.#{platform} #{value.inspect}"
              end

              public_send("#{platform}=", normalized)
            end

            self
          end
        end
      end
    end
  end
end
