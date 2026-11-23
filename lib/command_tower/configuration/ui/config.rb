# frozen_string_literal: true

require "tzinfo"
require "command_tower/ui/hostname"

module CommandTower
  module Configuration
    module UI
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        # Reads return exact hosts, lowercased and IDN (punycode) normalized.
        module NormalizedImageHosts
          def image_hosts
            super.map { |host| ::CommandTower::UI::Hostname.normalize(host) }.uniq
          end
        end

        ZONE_HELP = "Expected a TZInfo identifier such as America/Los_Angeles"
        HOSTS_DESC = "Exact image hosts allowed for document image nodes (https only). " \
                     "Fail closed: empty allows no images. Hosts are lowercased and " \
                     "IDN-normalized; no schemes, ports, paths or wildcards"

        add_composer(
          :default_zone,
          desc: "Default IANA time zone identifier for time nodes that do not name a zone",
          allowed: String,
          default: "UTC",
          validator: ->(val) { TZInfo::Timezone.all_identifiers.include?(val) },
          invalid_message: ->(val) { "Provided #{val.inspect}. #{ZONE_HELP}" }
        )

        add_composer(
          :image_hosts,
          desc: HOSTS_DESC,
          allowed: Array,
          default: [],
          default_shown: "[]",
          validator: ->(val) { val.none? { |host| ::CommandTower::UI::Hostname.normalize(host).nil? } },
          invalid_message: ->(_val) { "Expected an Array of bare host names (no scheme, port, path or wildcard)" }
        )

        prepend NormalizedImageHosts
      end
    end
  end
end
