# frozen_string_literal: true

module CommandTower
  module Messaging
    # The definition behind admin announcements (design D26). A host attaches it to a promotional
    # notification type (`message: "CommandTower::Messaging::AnnouncementDefinition"`) and the admin
    # announcement endpoint maps the admin's `title` and `body` into the metadata below.
    #
    # There is no fact block: documents validate with the `:default` profile, and the inbox and
    # email composers are a `Header` (the title) over the `Markdown` fragment (the body).
    class AnnouncementDefinition < MessageDefinition
      TITLE_MAX = 200
      BODY_MARKDOWN_MAX = 5000
      PUSH_BODY_MAX = 178

      class Metadata < CommandTower::Messaging::MessageDefinition::Metadata
        attribute :title, :string
        attribute :body_markdown, :string

        validates :title, presence: true, length: { maximum: TITLE_MAX }
        validates :body_markdown, presence: true, length: { maximum: BODY_MARKDOWN_MAX }
      end

      metadata_version 1
      metadata_schema Metadata
      promotional true
      document_profile :default

      fixture :default, metadata: {
        "title" => "New classes this week",
        "body_markdown" => "We added **three** classes.\n\n- Sunrise Stretch\n- Arms & Abs\n\n" \
                           "See the [schedule](/schedule) to book."
      }

      class << self
        # Resolved when read so a host's `config.ui.default_zone` is honoured.
        def default_zone(zone = nil)
          return super if zone

          super || CommandTower.config.ui.default_zone
        end
      end

      def inbox(builder, metadata:)
        compose(builder, metadata)
      end

      def email(builder, metadata:)
        compose(builder, metadata)
      end

      def headline(metadata:)
        metadata["title"]
      end

      def slots(metadata:, **)
        title = metadata["title"].to_s
        push = derived_text(metadata["body_markdown"]).presence || title
        {
          headline: title,
          subject: title,
          push_body: push,
          pushover_message: push,
          sms_body: "#{CommandTower.app_name_for_comms}: #{title}"
        }
      end

      private

      def compose(builder, metadata)
        builder.card(surface: :raised) do |c|
          c.fragment(CommandTower::UI::Fragments::Header, title: metadata["title"])
          c.fragment(CommandTower::UI::Fragments::Markdown, source: metadata["body_markdown"])
        end
      end

      # Plain text of the rendered markdown on one line, cut to the push/Pushover limit.
      def derived_text(markdown)
        return "" if markdown.blank?

        scratch = CommandTower::UI::Builder.new
        scratch.fragment(CommandTower::UI::Fragments::Markdown, source: markdown)
        text = scratch.roots.map { |node| CommandTower::UI::TextDerivation.call(node) }.join(" ")
        text.squish.truncate(PUSH_BODY_MAX, omission: "…")
      end
    end
  end
end
