# frozen_string_literal: true

RSpec.describe CommandTower::UI::Email::Renderer, :aggregate_failures do
  let(:palette) do
    {
      "background" => "#F9FAFB", "card" => "#FFFFFF", "border" => "#D5DAE2",
      "primary" => "#17758C", "primaryForeground" => "#FFFFFF", "foreground" => "#161D27",
      "textPrimary" => "#161D27", "textSecondary" => "#5E6978", "muted" => "#EAEDF0",
      "mutedForeground" => "#5E6978", "success" => "#358D64", "warning" => "#F59F0A",
      "danger" => "#DC2828"
    }
  end
  let(:options) { {} }
  let(:output) { described_class.call(document, palette:, origin: "https://app.example.com", **options) }
  let(:html) { output.html }

  before { allow(CommandTower.config.ui).to receive(:image_hosts).and_return(["img.example.com"]) }

  context "with a plain text document" do
    let(:document) { CommandTower::UI.document(text_fallback: "Fallback") { |d| d.text("Hello") } }

    it "returns html and text outputs" do
      expect(html).to include("<!DOCTYPE html>", "Hello")
      expect(output.text).to eq("Hello")
    end

    it "uses the derived text as the hidden preheader" do
      expect(html).to include('aria-hidden="true"', ">Hello</span>")
    end

    context "with footer, app name and preheader" do
      let(:options) { { footer_html: "<p>Unsubscribe</p>".html_safe, app_name: "Pickem", preheader: "Custom <pre>" } }

      it "passes them to the layout" do
        expect(html).to include("Unsubscribe", ">Pickem</td>", ">Custom &lt;pre&gt;</span>")
      end
    end

    context "with an unknown chrome option" do
      let(:options) { { subject_line: "x" } }

      it "raises" do
        expect { output }.to raise_error(ArgumentError)
      end
    end

    it "rejects bad origins" do
      ["javascript:alert(1)", "https://a.com/path", "https://u@a.com", "", nil].each do |bad|
        expect { described_class.call(document, palette:, origin: bad) }
          .to raise_error(CommandTower::UI::InvalidTokenError)
      end
    end

    it "rejects missing keys, extra keys and non #RRGGBB palette values" do
      [palette.except("danger"), palette.merge("accent" => "#000000"), palette.merge("danger" => "red")].each do |bad|
        expect { described_class.call(document, palette: bad, origin: "https://app.example.com") }
          .to raise_error(CommandTower::UI::InvalidTokenError)
      end
    end
  end

  context "with escaping-sensitive content" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.text("<b>Tom & Jerry</b>")
          s.banner("a < b", title: "\"Q\" & <A>", tone: :warning)
          s.badge("<i>x</i>")
          s.button "Go & <see>", action: d.navigate(href: "https://example.com/?a=1&b=2")
        end
      end
    end

    it "escapes text, titles, labels and attributes" do
      expect(html).to include("&lt;b&gt;Tom &amp; Jerry&lt;/b&gt;", "a &lt; b", "&lt;i&gt;x&lt;/i&gt;")
      expect(html).to include("Go &amp; &lt;see&gt;", "https://example.com/?a=1&amp;b=2")
      expect(html).not_to include("<b>Tom", "<i>x")
    end
  end

  context "with every text tone and a primary button" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          %i[primary secondary muted accent].each { |tone| s.text(tone.to_s, text_tone: tone) }
          s.button "Go", action: d.navigate(path: "/x"), variant: :primary
        end
      end
    end

    it "uses palette token colours" do
      expect(html).to include("color:#161D27;", "color:#5E6978;", "color:#17758C;", "background-color:#17758C;")
    end

    context "with a distinct mutedForeground" do
      let(:palette) { super().merge("mutedForeground" => "#123456") }

      it "backs the muted tone with mutedForeground" do
        expect(html).to include("color:#123456;")
      end
    end
  end

  describe "tint hex table with the fixture palette (section 5.C)" do
    {
      neutral: %w[#F7F8F9 #D5DAE2], accent: %w[#E8F1F4 #B9D6DD], success: %w[#EBF4F0 #C2DDD1],
      warning: %w[#FEF5E7 #FCE2B6], danger: %w[#FCEAEA #F5BFBF]
    }.each do |tone, (background, border)|
      context "with a #{tone} banner" do
        let(:document) { CommandTower::UI.document(text_fallback: "x") { |d| d.banner("x", tone:) } }

        it "blends to #{background} / #{border}" do
          expect(html).to include("background-color:#{background};border:1px solid #{border}")
        end
      end
    end

    context "with a tinted card and a toneless stat tile" do
      let(:document) do
        CommandTower::UI.document(text_fallback: "x") do |d|
          d.stack do |s|
            s.card(surface: :tinted, tone: :warning) { |c| c.text("w") }
            s.stat_tile(value: "9", label: "Streak")
          end
        end
      end

      it "uses the tone tint and the neutral tint" do
        expect(html).to include("background-color:#FEF5E7;border:1px solid #FCE2B6")
        expect(html).to include("background-color:#F7F8F9;border:1px solid #D5DAE2")
      end
    end
  end

  context "with a code node" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack { |s| s.code(value: "SECRET-1234", label: "Check-in", format: :text) }
      end
    end

    it "is rejected with path and code only" do
      expect { output }.to raise_error(CommandTower::UI::InvalidDocumentError) { |error|
        expect(error.details).to eq([{ path: "root.children[0]", code: "code_not_allowed" }])
        expect(error.message).not_to include("SECRET-1234")
      }
    end
  end

  context "with a code node inside a component fallback" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.component(key: "ticket") { |c| c.code(value: "SECRET", label: "Code", format: :qr) }
      end
    end

    it "is rejected" do
      expect { output }.to raise_error(CommandTower::UI::InvalidDocumentError, /code_not_allowed/)
    end
  end

  context "with internal and external links" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.text("See ", d.link("classes", action: d.navigate(path: "/classes?x=1")))
          s.button "Go", action: d.navigate(path: "/book")
          s.button "Mail", action: d.navigate(href: "mailto:me@example.com")
        end
      end
    end

    it "prefixes internal paths with the origin and keeps external hrefs" do
      expect(html).to include('href="https://app.example.com/classes?x=1"', 'href="https://app.example.com/book"')
      expect(html).to include('href="mailto:me@example.com"')
    end
  end

  context "with a component" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") { |d| d.component(key: "picks.grid") { |c| c.text("Fallback body") } }
    end

    it "renders the fallback tree only" do
      expect(html).to include("Fallback body")
      expect(html).not_to include("picks.grid")
    end
  end

  describe "countdown" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.time(at: "2025-12-04T14:00:00Z", zone: "America/Los_Angeles", format: :countdown)
      end
    end

    it "renders as the short format" do
      expect(html).to include("Thu, Dec 4, 6:00 AM PT")
    end
  end

  context "with images" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.image(src: "https://img.example.com/a.png", aspect: 2.0, alt: "A <pic>")
          s.image(src: "https://img.example.com/b.png", aspect: 1.0, decorative: true)
        end
      end
    end

    it "gives explicit width and height from the aspect, with escaped alt" do
      expect(html).to include('src="https://img.example.com/a.png"', 'alt="A &lt;pic&gt;"')
      expect(html).to include('width="552"', 'height="276"', 'height="552"')
    end

    it "gives decorative images an empty alt" do
      expect(html).to include('alt=""')
    end
  end

  context "with a disallowed image host" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") { |d| d.image(src: "https://evil.example.net/a.png", aspect: 1.0, alt: "x") }
    end

    it "is rejected" do
      expect { output }.to raise_error(CommandTower::UI::InvalidDocumentError)
    end
  end

  context "with icons" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.stat_tile(value: "1", label: "Wins", icon: "trophy")
          s.key_value { |kv| kv.item "When", "Now", icon: "clock" }
        end
      end
    end

    it "drops them" do
      expect(html).to include("Wins", "When")
      expect(html).not_to include("trophy", "clock", "<svg")
    end
  end

  context "with ghost and secondary buttons" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.button "Ghost", action: d.navigate(path: "/g"), variant: :ghost
          s.button "Second", action: d.navigate(path: "/s"), variant: :secondary
        end
      end
    end

    it "renders the ghost button as an underlined link" do
      expect(html).to match(
        %r{<a href="https://app.example.com/g" style="color:#17758C;text-decoration:underline;[^"]*">Ghost</a>}
      )
    end

    it "renders the secondary button on palette.background with a border" do
      expect(html).to include("background-color:#F9FAFB;border:1px solid #D5DAE2", "padding:9px 15px")
    end
  end

  context "with an invalid document" do
    let(:document) do
      CommandTower::UI::Document.new(root: CommandTower::UI::Nodes::Stack.new(children: []), text_fallback: "")
    end

    it "is rejected" do
      expect { output }.to raise_error(CommandTower::UI::InvalidDocumentError)
    end
  end

  context "with an unsafe external href built around validation" do
    let(:document) do
      action = CommandTower::UI::Nodes::Action::Navigate.new(href: "javascript:alert(1)")
      button = CommandTower::UI::Nodes::Button.new(label: "Go", action:)
      CommandTower::UI::Document.new(root: CommandTower::UI::Nodes::Stack.new(children: [button]), text_fallback: "x")
    end

    it "is rejected" do
      expect { output }.to raise_error(CommandTower::UI::InvalidDocumentError)
    end
  end

  context "with a stack, key_value and facts" do
    let(:document) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.text("Line one")
          s.key_value { |kv| kv.item "When", "Tonight" }
        end
      end
    end

    it "derives the text part from the node tree" do
      expect(output.text).to eq("Line one\nWhen: Tonight")
    end

    it "keeps every layout table presentational" do
      expect(html.scan("<table").size).to eq(html.scan('<table role="presentation"').size)
    end
  end
end
