# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      module Action
        # `navigate` action. Exactly one destination:
        #   path: internal, "/" not "//" (see Hardening.internal_path?)
        #   href: external, https (plus mailto and tel), no userinfo
        # Wire: { type: "navigate", destination: { kind: "internal", path: } | { kind: "external", href: } }
        class Navigate < Base
          attribute :path, :string
          attribute :href, :string

          validate :single_valid_destination

          def wire_type
            "navigate"
          end

          def as_json(_options = nil)
            { "type" => wire_type, "destination" => destination_json }
          end

          private

          def destination_json
            return { "kind" => "external", "href" => href } if path.nil?

            { "kind" => "internal", "path" => path }
          end

          def single_valid_destination
            return errors.add(:base, :destination_required) if path.nil? && href.nil?
            return errors.add(:base, :ambiguous_destination) if path && href

            validate_path if path
            validate_href if href
          end

          def validate_path
            errors.add(:path, :invalid_path) unless Hardening.internal_path?(path)
          end

          def validate_href
            code = Hardening.external_href_code(href)
            errors.add(:href, code) if code
          end
        end
      end
    end
  end
end
