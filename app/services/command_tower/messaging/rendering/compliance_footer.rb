# frozen_string_literal: true

require "erb"

module CommandTower
  module Messaging
    module Rendering
      # The compliance footer of a defined-type email (design D21, ux states E-01, E-03, E-06),
      # in the composed and the fallback email alike. Three copies: mandatory ("about your
      # account"), promotional (adds the postal address) and transactional. The preferences link
      # is `composed_url + preferences_path`, else `composed_url`. The footer never carries a
      # token and is identical whether or not the one-click headers are present.
      class ComplianceFooter
        Output = Data.define(:html, :text)

        PREFERENCES_LABEL = "Manage email preferences"
        PROMOTIONAL_LABEL = "Unsubscribe or manage email preferences"

        # @return [Output]
        def self.call(declaration:, definition:)
          new(declaration:, definition:).call
        end

        def initialize(declaration:, definition:)
          @declaration = declaration
          @definition = definition
        end

        def call
          lines = [copy]
          lines << [postal_address, nil] if promotional?
          Output.new(html: html_for(lines), text: text_for(lines))
        end

        private

        attr_reader :declaration, :definition

        def promotional?
          !declaration.mandatory && definition.promotional?
        end

        # @return [Array(String, String)] the sentence and the link label
        def copy
          app = CommandTower.app_name_for_comms
          return ["#{app} sends this email about your account.", PREFERENCES_LABEL] if declaration.mandatory

          because = "You're getting this email because"
          if promotional?
            ["#{because} #{declaration.label.to_s.downcase} are turned on for your #{app} account.", PROMOTIONAL_LABEL]
          else
            ["#{because} #{declaration.label} emails are turned on for your #{app} account.", PREFERENCES_LABEL]
          end
        end

        def postal_address
          CommandTower.config.messaging.compliance.postal_address.to_s
        end

        def preferences_url
          "#{CommandTower.config.application.composed_url}#{CommandTower.config.messaging.compliance.preferences_path}"
        end

        # Trusted, escaped HTML: every value goes through html_escape.
        def html_for(lines)
          lines.map do |text, label|
            escaped = ERB::Util.html_escape(text)
            next escaped unless label

            %(#{escaped} <a href="#{ERB::Util.html_escape(preferences_url)}">#{ERB::Util.html_escape(label)}</a>)
          end.join("<br>\n")
        end

        def text_for(lines)
          lines.map { |text, label| label ? "#{text} #{label}: #{preferences_url}" : text }.join("\n")
        end
      end
    end
  end
end
