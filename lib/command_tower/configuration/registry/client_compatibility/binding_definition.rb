# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module ClientCompatibility
        # Host-owned per-platform host-app version bound to a named client
        # contract. Authority §7.
        class BindingDefinition
          include ClassComposer::Generator

          add_composer :web, desc: "Bound host-app version for web", allowed: [String, NilClass], default: nil
          add_composer :ios, desc: "Bound host-app version for ios", allowed: [String, NilClass], default: nil
          add_composer :android, desc: "Bound host-app version for android", allowed: [String, NilClass], default: nil

          def for_platform(platform)
            public_send(platform)
          end

          def validate!(contract_id:)
            %i[web ios android].each do |platform|
              value = public_send(platform)
              next if value.blank?

              normalized = CommandTower::ClientCompatibility::Version.normalize(value)
              if normalized.nil?
                raise CommandTower::ClientCompatibility::InvalidVersionError,
                  "binding for client contract #{contract_id} has invalid #{platform} #{value.inspect}"
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
