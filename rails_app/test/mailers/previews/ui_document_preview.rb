# frozen_string_literal: true

# Mailer preview for UI document emails: /rails/mailers/ui_document/<fixture>.
# Each fixture is rendered by CommandTower::UI::Email::Renderer. The rake task
# `command_tower:ui:email_fixtures` writes the output to spec/fixtures/ui/email/.
class UiDocumentPreview < ActionMailer::Preview
  ORIGIN = "https://app.example.com"
  OUTPUT_DIR = File.expand_path("../../../../spec/fixtures/ui/email", __dir__)
  STARTS_AT = Time.utc(2025, 12, 4, 14, 0, 0)
  LA = "America/Los_Angeles"
  FOOTER_HTML = '<p style="margin:0;">You receive this because you booked a class. ' \
                '<a href="https://app.example.com/settings">Manage notifications</a></p>'

  # The default palette (design mocks, HSL) rounded to 8-bit hex.
  PALETTE = {
    "background" => "#F9FAFB", "card" => "#FFFFFF", "border" => "#D5DAE2",
    "primary" => "#17758C", "primaryForeground" => "#FFFFFF", "foreground" => "#161D27",
    "textPrimary" => "#161D27", "textSecondary" => "#5E6978", "muted" => "#EAEDF0",
    "mutedForeground" => "#5E6978", "success" => "#358D64", "warning" => "#F59F0A",
    "danger" => "#DC2828"
  }.freeze

  # Fixture name => chrome options passed to the renderer.
  CHROME = {
    "class_canceled_email" => {},
    "email_all_nodes" => {},
    "email_all_nodes_footer" => { footer_html: FOOTER_HTML.html_safe }, # rubocop:disable Rails/OutputSafety
    "email_app_name" => { app_name: "Sunrise Cycle" },
    "email_escaping" => {}
  }.freeze

  class << self
    def fixtures
      CHROME.keys
    end

    def output(fixture)
      CommandTower::UI::Email::Renderer.call(
        document(fixture), palette: PALETTE, origin: ORIGIN, **CHROME.fetch(fixture)
      )
    end

    def path(fixture, extension)
      File.join(OUTPUT_DIR, "#{fixture}.#{extension}")
    end

    def write_all
      FileUtils.mkdir_p(OUTPUT_DIR)
      fixtures.each do |fixture|
        result = output(fixture)
        File.write(path(fixture, "html"), result.html)
        File.write(path(fixture, "txt"), result.text)
      end
    end

    private

    def document(fixture)
      return email_escaping_document if fixture == "email_escaping"
      return class_canceled_email_document if fixture == "class_canceled_email"

      all_nodes_document
    end

    def class_canceled_email_document
      CommandTower::UI.document(text_fallback: "Your class was canceled.") do |d|
        # The email Layout draws the one container; the root is a plain stack.
        d.stack(gap: :lg) do |s|
          s.text "Sunrise Ride 45", variant: :title
          s.key_value do |kv|
            kv.item nil, kv.time(at: STARTS_AT, zone: LA, label: :always), icon: "calendar"
            kv.item nil, "Mission Street Studio", icon: "map-pin"
          end
          s.badge "Canceled", tone: :danger
          s.banner "No late-cancel fee was charged.", tone: :warning
          s.button "Find another class", action: s.navigate(path: "/classes"), variant: :primary
          s.button "View my bookings", action: s.navigate(path: "/bookings")
        end
      end
    end

    def all_nodes_document
      CommandTower::UI.document(text_fallback: "Every node.") do |d|
        d.stack(gap: :lg) { |s| all_nodes(s) }
      end
    end

    def all_nodes(stack)
      stack.text "Weekly summary ", stack.strong("bold"), " and ",
                 stack.link("a link", action: stack.navigate(path: "/me")), variant: :heading_m
      stack.divider
      stack.key_value do |kv|
        kv.item "Starts", kv.time(at: STARTS_AT, zone: LA, label: :never), icon: "calendar"
        kv.item "Studio", "Mission Street Studio"
      end
      stack.time at: STARTS_AT, zone: LA, format: :countdown
      stack.badge "Booked", tone: :success
      stack.banner "Heads up", title: "Notice", tone: :accent
      stack.stat_tile value: "7", label: "Picks remaining", tone: :warning, icon: "clock"
      stack.avatar initials: "DR", alt: "Coach Dana R."
      stack.image src: "https://img.example.com/studio.jpg", aspect: 1.5, alt: "The studio"
      stack.button "Open", action: stack.navigate(path: "/open"), variant: :primary
      stack.button "Not now", action: stack.navigate(href: "https://example.com/later"), variant: :ghost
      stack.component(key: "ct.example", data: {}) { |fallback| fallback.text "Fallback for a component" }
    end

    def email_escaping_document
      CommandTower::UI.document(text_fallback: "Escaping.") do |d|
        d.stack do |s|
          s.text "<b>Tom & Jerry</b>"
          s.banner "a < b", title: "\"Q\" & <A>", tone: :warning
          s.badge "<i>x</i>"
          s.button "Go & <see>", action: s.navigate(href: "https://example.com/?a=1&b=2")
        end
      end
    end
  end

  def class_canceled_email = message("class_canceled_email")
  def email_all_nodes = message("email_all_nodes")
  def email_all_nodes_footer = message("email_all_nodes_footer")
  def email_app_name = message("email_app_name")
  def email_escaping = message("email_escaping")

  private

  def message(fixture)
    result = self.class.output(fixture)
    UiDocumentMailer.document_email(html: result.html, text: result.text, subject: fixture.humanize)
  end
end
