# frozen_string_literal: true

RSpec.describe CommandTower::UI::Email::Styles, :aggregate_failures do
  # Default palette (design mocks, HSL) rounded to 8-bit hex.
  let(:palette) do
    {
      "background" => "#F9FAFB", "card" => "#FFFFFF", "border" => "#D5DAE2",
      "primary" => "#17758C", "primaryForeground" => "#FFFFFF", "foreground" => "#161D27",
      "textPrimary" => "#161D27", "textSecondary" => "#5E6978", "muted" => "#EAEDF0",
      "mutedForeground" => "#5E6978", "success" => "#358D64", "warning" => "#F59F0A",
      "danger" => "#DC2828"
    }
  end

  describe ".tint (section 5.C table)" do
    {
      "neutral" => ["#F7F8F9", "#D5DAE2"],
      "accent" => ["#E8F1F4", "#B9D6DD"],
      "success" => ["#EBF4F0", "#C2DDD1"],
      "warning" => ["#FEF5E7", "#FCE2B6"],
      "danger" => ["#FCEAEA", "#F5BFBF"]
    }.each do |tone, (background, border)|
      it "blends #{tone} onto card as #{background} / #{border}" do
        expect(described_class.tint(tone, palette)).to eq(background:, border:)
      end
    end

    it "blends onto palette.card, not white" do
      expect(described_class.tint("success", palette.merge("card" => "#000000"))[:background]).to eq("#050E0A")
    end

    it "rejects an unknown tone" do
      expect { described_class.tint("loud", palette) }.to raise_error(CommandTower::UI::InvalidTokenError)
    end
  end

  describe ".blend" do
    it "rounds exact halves up with exact arithmetic" do
      expect(described_class.blend("#17758C", "#FFFFFF", 0.1)).to eq("#E8F1F4") # blue 243.5
      expect(described_class.blend("#358D64", "#FFFFFF", 0.3)).to eq("#C2DDD1") # blue 208.5
    end
  end

  describe ".validate_palette!" do
    it "accepts the exact key set and returns a frozen copy" do
      expect(described_class.validate_palette!(palette)).to be_frozen
      expect(described_class::PALETTE_KEYS).to match_array(palette.keys)
    end

    it "rejects a missing key" do
      expect { described_class.validate_palette!(palette.except("danger")) }
        .to raise_error(CommandTower::UI::InvalidTokenError, /missing keys: danger/)
    end

    it "rejects an extra key" do
      expect { described_class.validate_palette!(palette.merge("accent" => "#000000")) }
        .to raise_error(CommandTower::UI::InvalidTokenError, /unknown keys: accent/)
    end

    it "rejects non #RRGGBB values without echoing them" do
      ["red", "#FFF", "#GGGGGG", "#FFFFFF; x:y", nil].each do |bad|
        expect { described_class.validate_palette!(palette.merge("primary" => bad)) }
          .to raise_error(CommandTower::UI::InvalidTokenError, /#RRGGBB: primary\z/)
      end
    end
  end
end
