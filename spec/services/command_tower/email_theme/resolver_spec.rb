# frozen_string_literal: true

RSpec.describe CommandTower::EmailTheme::Resolver do
  describe ".resolve" do
    subject(:result) { described_class.resolve }

    it "returns CommandTower's own default token set" do
      expect(result).to include(
        canvas_background: "#f4f5f7",
        surface_background: "#ffffff",
        surface_border: "#e2e8f0",
        primary_text: "#1a202c",
        body_text: "#4a5568",
        muted_text: "#718096",
        accent: "#2b6cb0",
        text_on_accent: "#ffffff",
        primary_action: "#2b6cb0"
      )
    end

    it "composes product identity from the existing application config" do
      expect(result).to include(
        product_name: CommandTower.app_name_for_comms,
        product_url: CommandTower.config.application.composed_url
      )
    end

    it "returns a frozen Hash" do
      expect(result).to be_frozen
    end

    context "when the host has a config/ui_tokens.json" do
      let(:fixture_path) { File.expand_path("../../../fixtures/messaging/ui_tokens.json", __dir__) }

      before do
        allow(CommandTower::EmailTheme::TokenFile).to receive(:host_path).and_return(fixture_path)
      end

      it "derives its 9 colour keys from the token file, ignoring config.email_theme" do
        expect(result).to include(
          canvas_background: "#faf8f5", surface_background: "#ffffff", surface_border: "#ddd8d0",
          primary_text: "#191f2e", body_text: "#191f2e", muted_text: "#606776",
          accent: "#5c2fc6", text_on_accent: "#ffffff", primary_action: "#5c2fc6"
        )
      end

      it "still composes product identity" do
        expect(result).to include(product_name: CommandTower.app_name_for_comms)
      end
    end

    context "when the host has overridden theme and identity config" do
      around do |example|
        previous_accent = CommandTower.config.email_theme.accent
        previous_name = CommandTower.config.application.communication_name
        CommandTower.config.email_theme.accent = "#123456"
        CommandTower.config.application.communication_name = "Acme"
        example.run
      ensure
        CommandTower.config.email_theme.accent = previous_accent
        CommandTower.config.application.communication_name = previous_name
      end

      it "reflects the host's overridden values" do
        expect(result).to include(accent: "#123456", product_name: "Acme")
      end
    end
  end
end
