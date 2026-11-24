# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Internal Messaging::Rendering collaborator for `ChannelRenderer`. Renders the email HTML
      # and text parts of a MessageDefinition-backed communication (design D20).
      #
      # 1. The definition's email composer (or `:basic`) through `UI::Email::Renderer` with the
      #    resolved palette and `user_zone: render_zone`.
      # 2. When that raises (a composer error, a missing fact block, which the `:message` profile
      #    rejects, or a `code` node, which the renderer rejects): a CT-built fallback document
      #    (headline, the fact block's derived text when the facts composer still works, else the
      #    communication `body`, then a CTA from the deep link, design G2) through the same
      #    renderer. One `email_document_fallback` log line carries ids and the error class only.
      #
      # When the fallback also raises, the error propagates and `ChannelRenderer` uses the generic
      # ERB templates.
      class DefinedEmailRenderer
        def self.render(communication:, definition:)
          new(communication:, definition:).render
        end

        def initialize(communication:, definition:)
          @communication = communication
          @definition = definition
        end

        # @return [CommandTower::UI::Email::Renderer::Output]
        def render
          present(composed_document)
        rescue StandardError => e
          log_fallback(e)
          present(fallback_document)
        end

        private

        attr_reader :communication, :definition

        # The `:message` profile requires a fact block, so a definition without one raises here.
        def composed_document
          builder.email(definition: definition.new, context:)
        end

        def fact_document
          return @fact_document if defined?(@fact_document)

          @fact_document = builder.facts(definition: definition.new, context:)
        end

        def fallback_document
          text = fact_text.presence || communication.body.to_s.strip
          builder.email(definition: fallback_definition(text).new, context:, profile: :default)
        end

        # A definition built from the communication alone: headline, `text` lines in place of the
        # fact block, and the `:basic` button. It does not call the host definition.
        def fallback_definition(text)
          title = communication.title.to_s.strip
          Class.new(CommandTower::Messaging::MessageDefinition) do
            define_method(:facts) { |factory, **| text.each_line(chomp: true) { |line| factory.text(line) } }
            define_method(:headline) { |metadata:| metadata["headline"].presence || title }
          end
        end

        # Derived text of the fact block, or "" when the facts composer fails or yields nothing.
        def fact_text
          document = fact_document
          document ? CommandTower::UI::TextDerivation.call(document.root, user_zone: zone) : ""
        rescue StandardError
          ""
        end

        # The compliance footer is added here so the composed and the fallback email carry it alike.
        def present(document)
          footer = compliance_footer
          output = CommandTower::UI::Email::Renderer.call(
            document,
            palette: CommandTower::EmailTheme::Palette.resolve,
            origin: CommandTower.config.application.composed_url,
            user_zone: zone,
            app_name: CommandTower.app_name_for_comms,
            footer_html: footer.html
          )
          CommandTower::UI::Email::Renderer::Output.new(html: output.html, text: "#{output.text}\n\n#{footer.text}")
        end

        def compliance_footer
          declaration = NotificationTypes.lookup(communication.notification_type_key)
          ComplianceFooter.call(declaration:, definition:)
        end

        def builder
          CommandTower::Messaging::Definitions::DocumentBuilder
        end

        def zone
          communication.render_zone.presence || CommandTower.config.ui.default_zone
        end

        def context
          @context ||= CommandTower::Messaging::Definitions::RenderContext.new(
            notification_type_key: communication.notification_type_key,
            metadata: string_metadata,
            metadata_version: communication.metadata_version || definition.metadata_version,
            slots: communication.slots,
            render_zone: communication.render_zone
          )
        end

        def string_metadata
          stored = communication.metadata
          (stored.is_a?(Hash) ? stored : {}).transform_keys(&:to_s)
        end

        # Ids and the error class only: metadata values and error messages can quote user data.
        def log_fallback(error)
          Rails.logger.warn(
            "[command_tower] email_document_fallback communication_id=#{communication.id} " \
            "notification_type_key=#{communication.notification_type_key} error_class=#{error.class.name}"
          )
        end
      end
    end
  end
end
