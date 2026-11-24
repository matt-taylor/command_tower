# frozen_string_literal: true

RSpec.describe CommandTower::EmailTheme::Palette, :email_theme do
  let(:legacy_values) do
    described_class::LEGACY_TO_PALETTE.keys.index_with { |key| CommandTower.config.email_theme.public_send(key) }
  end
  let(:fixture_path) { File.expand_path("../../../fixtures/messaging/ui_tokens.json", __dir__) }
  let(:missing_path) { "/nonexistent/ui_tokens.json" }
  let(:default_palette) do
    CommandTower::EmailTheme::TokenFile.load_palette(CommandTower::EmailTheme::TokenFile::DEFAULT_PATH)
  end

  describe ".resolve" do
    it "has exactly the 13 PALETTE_KEYS" do
      expect(described_class.resolve(host_path: fixture_path).keys).to eq(CommandTower::UI::Email::Styles::PALETTE_KEYS)
    end

    it "uses the CT default when there is no host file and email_theme is untouched" do
      expect(described_class.resolve(host_path: missing_path)).to eq(default_palette)
    end

    it "uses the customised 9-key email_theme (legacy adapter) when there is no host file" do
      with_email_theme(accent: "#123456", primary_text: "#0a0b0c") do
        expect(described_class.resolve(host_path: missing_path)).to include(
          "primary" => "#123456", "textPrimary" => "#0a0b0c", **default_palette.slice("success", "warning", "danger")
        )
      end
    end

    it "prefers the host file over a customised email_theme" do
      with_email_theme(accent: "#123456") do
        expect(described_class.resolve(host_path: fixture_path))
          .to include("primary" => "#5c2fc6", "success" => "#30885c")
      end
    end

    it "validates through the renderer's palette contract" do
      expect { CommandTower::UI::Email::Styles.validate_palette!(described_class.resolve(host_path: fixture_path)) }
        .not_to raise_error
    end
  end

  describe ".legacy_keys_from" do
    it "derives the 9 legacy keys equal to config.email_theme when the palette is unchanged" do
      expect(described_class.legacy_keys_from(default_palette)).to eq(legacy_values)
    end

    it "derives from a host palette" do
      expect(described_class.legacy_keys_from(described_class.resolve(host_path: fixture_path)))
        .to include(canvas_background: "#faf8f5", accent: "#5c2fc6", body_text: "#191f2e")
    end
  end
end
