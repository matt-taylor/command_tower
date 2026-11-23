# frozen_string_literal: true

RSpec.describe CommandTower::UI::Email::Layout, :aggregate_failures do
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
  let(:html) { described_class.call(body_html: "<p>Body</p>", palette:, preheader: "Hello <b>&", **options) }

  it "renders the document head with light-only colour scheme" do
    expect(html).to include('<html lang="en">')
    expect(html).to include('<meta name="color-scheme" content="light">')
    expect(html).to include('<meta name="supported-color-schemes" content="light">')
    expect(html).not_to include("prefers-color-scheme")
  end

  it "renders the canvas and container values" do
    expect(html).to include("background-color:#F9FAFB", "padding:24px 16px", 'width="600"', "max-width:600px")
    expect(html).to include("background-color:#FFFFFF;border:1px solid #D5DAE2;border-radius:12px;padding:24px")
    expect(html).to include("<p>Body</p>")
  end

  it "sizes the container column from the frame width so content shrinks with it" do
    expect(html).to include("width:100%;max-width:600px;table-layout:fixed;")
  end

  it "does not fix the container column at 600px in CSS" do
    expect(html).not_to include('style="width:600px')
  end

  it "fixes the canvas table layout so the container's max-width resolves against the frame" do
    expect(html).to include("background-color:#F9FAFB;table-layout:fixed;")
  end

  it "marks layout tables presentational" do
    expect(html.scan("<table").size).to eq(html.scan('<table role="presentation"').size)
  end

  it "hides the escaped preheader from assistive tech" do
    expect(html).to match(%r{<span aria-hidden="true" style="display:none;[^"]*">Hello &lt;b&gt;&amp;</span>})
  end

  it "omits the footer and app-name rows when nil" do
    expect(html).not_to include("padding-top:16px")
    expect(html).not_to include("padding-bottom:12px")
  end

  context "with a footer" do
    let(:options) { { footer_html: "<i>foot</i>" } }

    it "renders the footer row outside, after the container" do
      expect(html).to include("padding-top:16px;font-size:14px;line-height:20px;color:#5E6978;\"><i>foot</i>")
      expect(html.index("<i>foot</i>")).to be > html.index("<p>Body</p>")
    end
  end

  it "draws exactly one bordered container" do
    expect(html.scan("border:1px solid #D5DAE2").size).to eq(1)
  end

  context "with footer links" do
    let(:options) { { footer_html: '<a href="https://x.test/a">One</a> <a href="/b" style="color:red;">Two</a>' } }

    it "underlines unstyled links in the footer text colour" do
      expect(html).to include('<a href="https://x.test/a" style="color:#5E6978;text-decoration:underline;">One</a>')
    end

    it "leaves a link that already has a style alone" do
      expect(html).to include('<a href="/b" style="color:red;">Two</a>')
    end
  end

  context "with an app name" do
    let(:options) { { app_name: "A & <B>" } }

    it "renders an escaped row above the container" do
      expect(html).to include("font-weight:600;color:#161D27;\">A &amp; &lt;B&gt;")
      expect(html.index("A &amp;")).to be < html.index("<p>Body</p>")
    end
  end

  it "validates the palette" do
    expect { described_class.call(body_html: "", palette: palette.except("card"), preheader: "p") }
      .to raise_error(CommandTower::UI::InvalidTokenError)
  end
end
