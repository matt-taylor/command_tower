# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # Builds the preview Hash for one declared fixture of one defined type, using the same pure
        # code the sender and the inbox read use. Reads no `Communication`. A composer that raises
        # raises {ChannelFailed}.
        class PreviewBuilder
          def self.call(**)
            new(**).call
          end

          def initialize(declaration:, definition:, fixture:, render_zone:, footer_notice: nil)
            @declaration = declaration
            @definition = definition
            @fixture = fixture
            @render_zone = render_zone
            @footer_notice = footer_notice
          end

          def call
            {
              notification_type_key: declaration.key, fixture:, metadata_version: definition.metadata_version,
              render_zone:, slots: PreviewChannels.slot_payload(context.slots), channels:,
              facts: facts_payload, checks:
            }
          end

          private

          attr_reader :declaration, :definition, :fixture, :render_zone, :footer_notice

          def instance
            @instance ||= definition.new
          end

          def builder
            CommandTower::Messaging::Definitions::DocumentBuilder
          end

          def context
            @context ||= begin
              base = CommandTower::Messaging::Definitions::RenderContext.new(
                notification_type_key: declaration.key, metadata: definition.fixtures.fetch(fixture),
                metadata_version: definition.metadata_version, slots: nil, render_zone:
              )
              base.with(slots: ChannelFailed.guard("slots") { builder.slots(definition: instance, context: base) })
            end
          end

          def inbox_wire
            return unless declaration.inbox_available

            ChannelFailed.guard("inbox") { builder.inbox(definition: instance, context:).as_json }
          end

          # nil when the composer fails; the email then shows the fallback.
          def email_wire
            return unless email_allowed?

            builder.email(definition: instance, context:).as_json
          rescue StandardError
            nil
          end

          def email_allowed?
            PreviewChannels.allowed?(declaration, "email")
          end

          def email
            PreviewEmail.call(definition:, context:, footer_notice:) if email_allowed?
          end

          def channels
            @channels ||= PreviewChannels.call(
              declaration:, slots: context.slots, link: context.metadata["deep_link"].to_s.presence,
              inbox: inbox_wire, email:
            )
          end

          def facts_document
            @facts_document ||= ChannelFailed.guard("facts") { builder.facts(definition: instance, context:) }
          end

          def facts_payload
            return { app: nil, email_html: nil } unless facts_document

            html = ChannelFailed.guard("facts") do
              CommandTower::UI::Email::Renderer.new(
                palette: CommandTower::EmailTheme::Palette.resolve,
                origin: CommandTower.config.application.composed_url, user_zone: render_zone
              ).render_body(facts_document)
            end
            { app: facts_document.as_json, email_html: html }
          end

          def checks
            PreviewChecks.call(
              definition:, context:,
              documents: { inbox: channels.dig(:inbox, :content), email: email_wire, facts: facts_document&.as_json },
              texts: rendered_texts, fact_text: fact_text
            )
          end

          def fact_text
            return "" unless facts_document

            CommandTower::UI::TextDerivation.call(facts_document.root, user_zone: render_zone)
          end

          def rendered_texts
            email = channels[:email]
            (context.slots.values + [email&.dig(:html), email&.dig(:text), channels.dig(:push, :body),
                                     channels.dig(:sms, :text), channels.dig(:pushover, :message)]).compact.map(&:to_s)
          end
        end
      end
    end
  end
end
