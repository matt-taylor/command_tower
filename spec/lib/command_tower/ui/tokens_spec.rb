# frozen_string_literal: true

RSpec.describe CommandTower::UI::Tokens, :aggregate_failures do
  let(:mapping) { described_class.mapping }
  let(:alpha_keys) { %w[tintBackgroundAlpha tintBorderAlpha neutralTintBackgroundAlpha neutralTintBorder] }
  let(:sans_stack) { "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif" }
  let(:mono_stack) do
    "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace"
  end

  describe ".mapping" do
    it "is parsed once" do
      expect(described_class.mapping).to equal(described_class.mapping)
    end

    it "is deep-frozen" do
      expect(mapping).to be_frozen
      expect(mapping["spacing"]).to be_frozen
      expect(mapping["typeSteps"]["body"]).to be_frozen
      expect(mapping["typeSteps"]["body"]["typography"]).to be_frozen
    end

    it "records the fixture version" do
      expect(mapping["fixtureVersion"]).to eq(1)
    end
  end

  describe "spacing (5.A)" do
    it "maps tokens to px" do
      expect(mapping["spacing"]).to eq("none" => 0, "xs" => 4, "sm" => 8, "md" => 12, "lg" => 16, "xl" => 24)
      expect(mapping["spacing"].keys).to eq(described_class::GAP)
    end

    it "looks up px by token" do
      expect(described_class.spacing_px(:md)).to eq(12)
    end
  end

  describe "type steps (5.B)" do
    {
      "display" => ["display", 36, 40, 700, "-0.025em", false, false, "primary"],
      "heading_xl" => ["headingXl", 30, 36, 600, "-0.025em", false, false, "primary"],
      "heading_l" => ["headingL", 24, 32, 600, nil, false, false, "primary"],
      "heading_m" => ["headingM", 20, 28, 600, nil, false, false, "primary"],
      "title" => ["title", 18, 28, 500, nil, false, false, "primary"],
      "subtitle" => ["subtitle", 16, 24, 500, nil, false, false, "secondary"],
      "body" => ["body", 16, 24, 400, nil, false, false, "primary"],
      "caption" => ["caption", 14, 20, 400, nil, false, false, "secondary"],
      "overline" => ["overline", 12, 16, 500, "0.1em", true, false, "secondary"],
      "mono" => ["mono", 14, 20, 400, nil, false, true, "primary"]
    }.each do |variant, (typography, size, line_height, weight, tracking, uppercase, mono, tone)|
      it "has #{variant}" do
        expect(described_class.type_step(variant)).to eq(
          "typography" => typography, "size" => size, "lineHeight" => line_height, "weight" => weight,
          "tracking" => tracking, "uppercase" => uppercase, "mono" => mono, "defaultTextTone" => tone
        )
      end
    end

    it "covers exactly the VARIANT enum" do
      expect(mapping["typeSteps"].keys).to eq(described_class::VARIANT)
    end

    it "raises InvalidTokenError for an unknown variant" do
      expect { described_class.type_step("huge") }.to raise_error(CommandTower::UI::InvalidTokenError)
    end
  end

  describe "fonts" do
    it "holds the email font stacks" do
      expect(mapping["fonts"]["sans"]).to eq(sans_stack)
      expect(mapping["fonts"]["mono"]).to eq(mono_stack)
    end
  end

  describe "tones and alphas (5.C)" do
    it "maps tone to palette key" do
      expect(mapping["tones"].keys).to eq(described_class::TONE)
      expect(mapping["tones"].transform_values { |tone| tone["paletteKey"] }).to eq(
        "neutral" => "muted", "accent" => "primary", "success" => "success",
        "warning" => "warning", "danger" => "danger"
      )
    end

    it "keeps the neutral border on the border palette key" do
      expect(mapping["tones"]["neutral"]["borderPaletteKey"]).to eq("border")
      expect(described_class.tone_palette_key("accent")).to eq("primary")
    end

    it "has the alphas" do
      expect(mapping.slice(*alpha_keys)).to eq(
        "tintBackgroundAlpha" => 0.10, "tintBorderAlpha" => 0.30,
        "neutralTintBackgroundAlpha" => 0.40, "neutralTintBorder" => "border"
      )
    end

    it "raises InvalidTokenError for an unknown tone" do
      expect { described_class.tone_palette_key("pink") }.to raise_error(CommandTower::UI::InvalidTokenError)
    end
  end

  describe "text tones (8.A2)" do
    it "allows only the four tones" do
      expect(described_class::TEXT_TONE).to eq(%w[primary secondary muted accent])
      expect(mapping["textTones"].keys).to eq(described_class::TEXT_TONE)
    end

    it "backs muted with mutedForeground" do
      expect(mapping["textTones"]["muted"]).to eq("mutedForeground")
    end
  end

  describe "avatar sizes" do
    it "maps sizes to px" do
      expect(mapping["avatarSizes"]).to eq("sm" => 24, "md" => 32, "lg" => 48)
      expect(described_class.avatar_px(:lg)).to eq(48)
    end
  end

  describe "enums" do
    it "defines the remaining enums" do
      expect(described_class::SURFACE).to eq(%w[raised tinted plain])
      expect(described_class::ALIGN).to eq(%w[start center end between])
      expect(described_class::BUTTON_VARIANT).to eq(%w[primary secondary ghost])
      expect(described_class::AVATAR_SIZE).to eq(%w[sm md lg])
    end
  end
end
