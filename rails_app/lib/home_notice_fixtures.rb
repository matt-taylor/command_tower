# frozen_string_literal: true

require "json"

# `GET /me/home-notices` response fixtures for the home notices states (`states.md` §7). `rake
# command_tower:home_notices:fixtures` (or `HomeNoticeFixtures.write_all!`) writes them under
# `spec/fixtures/home_notices/`, so the frontend preview app can copy them byte for byte.
#
#   terms, terms_long   blocking notice with an https button and an https link span
#   campaign            dismissible campaign with a primary internal CTA
#   update_app          `ct.update_app` with an https update URL
#   update_app_nourl    `ct.update_app` without a usable update URL
#   linked              dismissible linked delivery showing an inbox item's own document
#   code                blocking notice whose `code` node is redacted; `readOnly: true`
#   both                a blocking and a dismissible notice
#   none                nothing to present
#
# Notices compose through the production `Compose` service (profiles, redaction and the payload
# serializer), so a fixture is what the endpoint would return. Values are fictional. Output is
# deterministic: fixed clock, fixed ids, sorted keys.
module HomeNoticeFixtures
  DIR = File.expand_path("../../spec/fixtures/home_notices", __dir__)

  Campaign = CommandTower::HomeNotices::Campaign
  Pick = CommandTower::Services::HomeNotices::PickNotices::Pick
  NOW = Time.utc(2026, 11, 24, 17, 0, 0)
  UPDATE_URL = "https://apps.example.com/studio"

  # Blocking terms notice: an https button (not primary) and an https link span.
  class TermsNotice < Campaign
    key "studio.terms_update"
    severity :blocking
    priority 90
    blocking_reason "Studio terms changed and the member must accept them."
    window ends_at: Time.utc(2026, 12, 31, 23, 59, 59)

    def compose(builder, **)
      builder.card(surface: :raised) do |card|
        card.text("Studio terms updated", variant: :heading_m)
        card.text("We changed how cancellations work. Read our ",
                  card.link("cancellation policy", action: card.navigate(href: "https://studio.example.com/policy")),
                  " before you book again.")
        card.button("Read the full terms", action: card.navigate(href: "https://studio.example.com/terms"))
      end
    end
  end

  # The same notice with enough sections to scroll.
  class LongTermsNotice < TermsNotice
    key "studio.terms_update_long"

    def compose(builder, **)
      builder.card(surface: :raised) do |card|
        card.text("Studio terms updated", variant: :heading_m)
        (1..14).each do |number|
          card.text("Section #{number}", variant: :title)
          card.text("Members agree to the studio rules in section #{number}. Late cancellations within twelve " \
                    "hours of a class may use a class credit. Credits expire sixty days after purchase.")
        end
        card.button("Read the full terms", action: card.navigate(href: "https://studio.example.com/terms"))
      end
    end
  end

  # Blocking notice carrying a check-in code. Impersonation redacts the code to one text node.
  class CodeNotice < Campaign
    key "studio.check_in"
    severity :blocking
    priority 80
    blocking_reason "The member must see today's check-in code."

    def compose(builder, **)
      builder.card(surface: :raised) do |card|
        card.text("Check in for Arms & Abs", variant: :heading_m)
        card.code(value: "482913", label: "Check-in code", format: :text)
      end
    end
  end

  # Dismissible campaign whose primary button is the internal CTA the client lifts to the footer.
  class PreferencesNotice < Campaign
    key "studio.preferences"
    severity :dismissible
    priority 20
    impressions max: 3, cooldown: 12.hours
    window ends_at: Time.utc(2026, 12, 15, 23, 59, 59)

    def compose(builder, **)
      builder.card(surface: :raised) do |card|
        card.text("Tell us how you like to train", variant: :heading_m)
        card.text("Pick your favourite class types and we will suggest the right sessions.")
        card.button("Set preferences", action: card.navigate(path: "/preferences"), variant: :primary)
      end
    end
  end

  # Dismissible linked delivery: the document is the member's own `class_canceled` inbox item.
  class LinkedNotice < CommandTower::HomeNotices::Delivery
    key "studio.class_canceled"
    severity :dismissible
    priority 70
    composer :message
  end

  # The inbox composition of the linked message, with the CTA group the client lifts.
  class LinkedClassCanceled < ClassCanceled
    def inbox(builder, metadata:)
      builder.card(surface: :raised) do |card|
        card.text(metadata["headline"], variant: :heading_m)
        card.facts
        card.fragment CommandTower::UI::Fragments::CtaGroup, buttons: [
          { label: "Find another class", action: card.navigate(path: "/classes"), variant: :primary }
        ]
      end
    end
  end

  class << self
    # @return [Hash{String => String}] absolute path => file content, in write order
    def files
      selections.to_h { |name, selection| [File.join(DIR, "#{name}.json"), json(selection)] }
    end

    def write_all!
      FileUtils.mkdir_p(DIR)
      files.each { |path, content| File.write(path, content) }
      files.length
    end

    private

    def selections
      terms = pick(TermsNotice)
      campaign = pick(PreferencesNotice)
      {
        "terms" => selection(blocking: terms),
        "terms_long" => selection(blocking: pick(LongTermsNotice)),
        "campaign" => selection(dismissible: campaign),
        "both" => selection(blocking: terms, dismissible: campaign),
        "none" => selection
      }.merge(special_selections)
    end

    def special_selections
      {
        "update_app" => selection(dismissible: update_app_pick(update_url: UPDATE_URL)),
        "update_app_nourl" => selection(dismissible: update_app_pick(update_url: nil)),
        "linked" => selection(dismissible: linked_pick),
        "code" => selection(blocking: pick(CodeNotice, impersonating: true), read_only: true)
      }
    end

    def selection(blocking: nil, dismissible: nil, read_only: false)
      CommandTower::Serializers::HomeNotices::SelectionSerializer.serialize(blocking:, dismissible:, read_only:)
    end

    def pick(notice_class, compatibility: nil, impersonating: false)
      result = CommandTower::Services::HomeNotices::Compose.call(
        notice_class:, user: User.new, request_context: context(compatibility:, impersonating:), record: nil
      )
      document = result.data[:document]
      raise "Home notice fixture #{notice_class.key} did not compose: #{result.errors}" if document.nil?

      Pick.new(notice_class:, record: nil, document:, content_hash: result.data[:content_hash])
    end

    def update_app_pick(update_url:)
      compatibility = { updateAvailable: true, recommendedVersion: "1.4.0", updateUrl: update_url }
      pick(CommandTower::HomeNotices::Campaigns::UpdateApp, compatibility:)
    end

    def linked_pick
      document = linked_document
      record = CommandTower::HomeNotices::NoticeRecord.new(
        public_id: "hn_fixture_class_canceled", kind: "delivery", key: LinkedNotice.key, campaign_key: nil,
        period_key: nil, identity: "fixture", communication_id: 1, starts_at: nil, ends_at: Time.utc(2026, 12, 4, 22),
        metadata: {}.freeze, impression_count: 0, first_shown_at: nil, last_shown_at: nil, acknowledged_at: nil,
        dismissed_until: nil
      )
      Pick.new(notice_class: LinkedNotice, record:, document:, content_hash: nil)
    end

    # What `Compose` takes from `Messaging::Contract::Inbox.document_for_communication`, built
    # without a database row: the definition's inbox document, validated and redacted.
    def linked_document
      metadata = LinkedClassCanceled.fixtures.fetch("default")
      message_context = CommandTower::Messaging::Definitions::RenderContext.new(
        notification_type_key: "class_canceled", metadata:, metadata_version: 1, slots: {},
        render_zone: "America/New_York"
      )
      document = CommandTower::Messaging::Definitions::DocumentBuilder.inbox(
        definition: LinkedClassCanceled.new, context: message_context, profile: LinkedClassCanceled.document_profile
      )
      CommandTower::UI::Redaction.call(document.validate!(profile: :default), impersonating: false)
    end

    def context(compatibility:, impersonating:)
      CommandTower::HomeNotices::Context.new(
        now: NOW, time_zone: "America/New_York", app_version: "1.2.0", platform: "web", ui_catalog: 2,
        client_compatibility: compatibility, impersonating:
      )
    end

    # Pretty-printed JSON with deeply sorted keys and a trailing newline.
    def json(value)
      "#{JSON.pretty_generate(sort_keys(value.as_json))}\n"
    end

    def sort_keys(value)
      case value
      when Hash then value.sort_by { |key, _| key.to_s }.to_h { |key, inner| [key, sort_keys(inner)] }
      when Array then value.map { |inner| sort_keys(inner) }
      else value
      end
    end
  end
end
