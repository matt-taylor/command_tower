# frozen_string_literal: true

require "action_view"
require "command_tower/ui/email/renderer/styling"
require "command_tower/ui/email/renderer/containers"
require "command_tower/ui/email/renderer/text_nodes"
require "command_tower/ui/email/renderer/inline_nodes"

module CommandTower
  module UI
    module Email
      # Renders a validated UI document to table-based, inline-styled email HTML
      # plus a plain-text part. Spec: design ux/states.md sections 5 and 8.
      #
      # - Escaping is done by ActionView's TagHelper; document values are never
      #   interpolated into markup.
      # - `code` nodes are rejected (InvalidDocumentError, path and code only):
      #   a check-in code never reaches an email.
      # - Conversions: component -> fallback tree; internal navigate ->
      #   `origin + path`; countdown -> short; icons dropped; ghost button ->
      #   underlined link; image width/height derived from `aspect`.
      # - Text colour comes from `textTone` (the node default is "primary", so a
      #   variant's own default tone, for example subtitle, is not applied).
      #
      # Optional chrome keywords: `footer_html:` (trusted, escaped HTML),
      # `app_name:` and `preheader:` (plain text), passed to {Layout}.
      # `user_zone:` (default `config.ui.default_zone`) is the zone `zone: "user"` times render in.
      class Renderer
        Output = Data.define(:html, :text)

        ORIGIN_FORMAT = %r{\Ahttps?://[^\s/?#@\\]+\z}
        PREHEADER_LIMIT = 110
        CHROME_KEYS = %i[footer_html app_name preheader].freeze
        TABLE = { role: "presentation", cellpadding: 0, cellspacing: 0, border: 0 }.freeze
        # Full-width body tables use a fixed layout so they shrink with the container;
        # in auto layout a wide image's width attribute keeps the table from shrinking.
        FILL_TABLE = TABLE.merge(width: "100%", style: "table-layout:fixed;").freeze
        HANDLERS = {
          Nodes::Stack => :stack, Nodes::Facts => :facts, Nodes::Card => :card, Nodes::Divider => :divider,
          Nodes::Text => :text, Nodes::Instant => :instant, Nodes::KeyValue => :key_value,
          Nodes::Badge => :badge, Nodes::Button => :button, Nodes::Image => :image,
          Nodes::Banner => :banner, Nodes::Avatar => :avatar, Nodes::StatTile => :stat_tile,
          Nodes::Component => :component
        }.freeze

        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::OutputSafetyHelper
        include Styling
        include Containers
        include TextNodes
        include InlineNodes

        def self.call(document, palette:, origin:, user_zone: CommandTower.config.ui.default_zone, **chrome)
          new(palette:, origin:, user_zone:).render_document(document, **chrome.assert_valid_keys(*CHROME_KEYS))
        end

        def initialize(palette:, origin:, user_zone: CommandTower.config.ui.default_zone)
          @user_zone = user_zone
          @palette = Styles.validate_palette!(palette)
          valid_origin = origin.is_a?(String) && ORIGIN_FORMAT.match?(origin)
          raise InvalidTokenError, "origin must be an http(s) origin" unless valid_origin

          @origin = origin
        end

        def render_document(document, preheader: nil, **chrome)
          reject_code!(document.root, "root")
          document.validate!
          derived = TextDerivation.call(document.root, user_zone: @user_zone)
          preheader ||= derived.gsub(/\s+/, " ").strip.truncate(PREHEADER_LIMIT)
          html = Layout.call(body_html: render(document.root).to_str, palette: @palette, preheader:, **chrome)
          text = TextPart.call(document.root, origin: @origin, user_zone: @user_zone)
          Output.new(html:, text:)
        end

        private

        def reject_code!(object, path)
          reject!(path, :code_not_allowed) if object.is_a?(Nodes::Code)
          object.each_child { |relative, child| reject_code!(child, "#{path}.#{relative}") }
        end

        def render(node)
          handler = HANDLERS[node.class]
          reject!("root", :invalid_node) unless handler

          send(handler, node)
        end
      end
    end
  end
end
