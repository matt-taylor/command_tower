# frozen_string_literal: true

module CommandTower
  module Messaging
    module Definitions
      # The `d` a MessageDefinition composer receives. It is a `UI::Builder` that also knows the
      # definition and the {RenderContext}, so a composer can say:
      #
      #   def inbox(d, metadata:)
      #     d.card(surface: :raised) { |c| c.facts; c.button "Find a class", action: d.navigate(path: "/schedule") }
      #   end
      #
      # - `d.facts` / `c.facts` with no block inserts the definition's fact block.
      # - `d.basic` builds the `:basic` layout: a raised card with the headline, the fact block and
      #   a primary button (no button without a safe deep link).
      # - `d.t.(at, zone:, format:)` renders a time with the zone label always shown; `zone: :user`
      #   resolves to the context's `render_zone`.
      #
      # Pure: no DB, no network. The class methods return validated documents (profile `:message`
      # unless told otherwise) and raise `UI::InvalidDocumentError` (paths and codes only).
      class DocumentBuilder < CommandTower::UI::Builder
        DEFAULT_PROFILE = :message

        class << self
          # @return [CommandTower::UI::Document] the definition's inbox document
          def inbox(definition:, context:, profile: DEFAULT_PROFILE)
            document(definition:, context:, profile:) do |builder|
              definition.inbox(builder, metadata: context.metadata)
            end
          end

          # @return [CommandTower::UI::Document] the definition's email document
          def email(definition:, context:, profile: DEFAULT_PROFILE)
            document(definition:, context:, profile:) do |builder|
              definition.email(builder, metadata: context.metadata)
            end
          end

          # The fact block alone as a document, or nil when the definition has no fact block.
          # @return [CommandTower::UI::Document, nil]
          def facts(definition:, context:, profile: DEFAULT_PROFILE)
            builder = new(definition:, context:)
            builder.facts
            return nil if builder.roots.empty?

            finish(builder, context:, profile:)
          end

          # Channel slots as a symbol-keyed Hash; nil values are dropped.
          # @return [Hash{Symbol => String}]
          def slots(definition:, context:)
            builder = new(definition:, context:)
            raw = definition.slots(metadata: context.metadata, t: builder.t)
            raw.to_h.transform_keys(&:to_sym).compact
          end

          private

          def document(definition:, context:, profile:)
            builder = new(definition:, context:)
            yield builder
            finish(builder, context:, profile:)
          end

          # Same root rule as `UI.document`: exactly one root node.
          def finish(builder, context:, profile:)
            roots = builder.roots
            unless roots.one?
              code = roots.empty? ? "root_required" : "multiple_roots"
              raise UI::InvalidDocumentError.new("Invalid UI document: root:#{code}",
                                                 details: [{ path: "root", code: }])
            end

            built = UI::Document.new(root: roots.first, text_fallback: "-")
            built.validate!(profile:)
            fallback = UI::TextDerivation.call(built.root, user_zone: zone_for(context))
            UI::Document.new(root: built.root, text_fallback: fallback).validate!(profile:)
          end

          def zone_for(context)
            context.render_zone.presence || CommandTower.config.ui.default_zone
          end
        end

        def initialize(definition:, context:)
          super()
          @definition = definition
          @context = context
          @inserting_facts = false
        end

        # With a block: the base `facts` container. Without: the definition's fact block.
        def facts(&block)
          return super if block
          raise ArgumentError, "a definition's facts must not call d.facts without a block" if @inserting_facts

          @inserting_facts = true
          @definition.facts(self, metadata: @context.metadata)
        ensure
          @inserting_facts = false unless block
        end

        # Raised card: headline, fact block, primary button. The button needs a deep link.
        def basic
          card(surface: :raised) do |c|
            c.text(headline, variant: :heading_m)
            c.facts
            destination = deep_link_destination
            c.button(cta_label, action: navigate(**destination), variant: :primary) if destination
          end
        end

        # Zone-aware time formatter, `t.(at, zone:, format:)`.
        def t
          @t ||= lambda do |at, zone:, format:|
            UI::TimeFormatter.call(at:, zone:, format:, label: :always, user_zone: user_zone)
          end
        end

        private

        def user_zone
          @context.render_zone.presence || CommandTower.config.ui.default_zone
        end

        def headline
          slots = @context.slots
          stored = slots.respond_to?(:to_h) ? slots.to_h.transform_keys(&:to_s)["headline"] : nil
          stored.presence || @definition.headline(metadata: @context.metadata)
        end

        def cta_label
          label = metadata_value("cta_label")
          label.is_a?(String) && !label.strip.empty? ? label : "Open in #{CommandTower.app_name}"
        end

        # Internal path wins over an external href, as in the generic inbox document.
        def deep_link_destination
          path = metadata_value("deep_link_path")
          return { path: } if UI::Hardening.internal_path?(path)

          href = metadata_value("deep_link")
          { href: } if UI::Hardening.external_href_code(href).nil?
        end

        def metadata_value(key)
          metadata = @context.metadata
          metadata.is_a?(Hash) ? (metadata[key] || metadata[key.to_sym]) : nil
        end
      end
    end
  end
end
