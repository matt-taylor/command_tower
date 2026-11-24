# frozen_string_literal: true

RSpec.describe CommandTower::UI::TextDerivation, :aggregate_failures do
  let(:at) { Time.utc(2025, 12, 4, 14) }

  context "with spans" do
    let(:text) do
      UiSpecHelpers.derive_text do |d|
        d.text("Class ", d.strong("canceled"), d.link("details", action: d.navigate(path: "/c")))
      end
    end

    it "joins them without markup" do
      expect(text).to eq("Class canceleddetails")
    end
  end

  context "with a time" do
    let(:text) { UiSpecHelpers.derive_text { |d| d.time(at:, zone: "America/New_York", label: :never) } }

    it "shows the zone label always" do
      expect(text).to eq("Thu, Dec 4, 9:00 AM ET")
    end
  end

  context "with a zone user time" do
    let(:root) do
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          s.time(at:, zone: :user, format: :time)
          s.key_value { |kv| kv.item "When", kv.time(at:, zone: "user", format: :time) }
          s.time(at:, zone: "UTC", format: :time)
        end
      end.root
    end

    it "renders in the given user zone, leaving named zones alone" do
      expect(described_class.call(root, user_zone: "America/Los_Angeles"))
        .to eq("6:00 AM PT\nWhen: 6:00 AM PT\n2:00 PM UTC")
    end

    context "with a configured default zone" do
      before { allow(CommandTower.config.ui).to receive(:default_zone).and_return("America/New_York") }

      it "defaults to config.ui.default_zone" do
        expect(described_class.call(root)).to eq("9:00 AM ET\nWhen: 9:00 AM ET\n2:00 PM UTC")
      end
    end
  end

  context "with a time without a zone" do
    before { allow(CommandTower.config.ui).to receive(:default_zone).and_return("America/New_York") }

    let(:text) { UiSpecHelpers.derive_text { |d| d.time(at:, format: :time) } }

    it "defaults to the configured default zone (the render zone)" do
      expect(text).to eq("9:00 AM ET")
    end
  end

  context "with a component" do
    let(:text) do
      UiSpecHelpers.derive_text do |d|
        d.component(key: "ct.thing", data: { a: 1 }) { |c| c.text("Fallback copy") }
      end
    end

    it "uses the fallback tree" do
      expect(text).to eq("Fallback copy")
    end
  end

  context "with a code" do
    let(:text) do
      UiSpecHelpers.derive_text do |d|
        d.stack do |s|
          s.text "Your code"
          s.code value: "987654", label: "Door", format: :text
        end
      end
    end

    it "excludes its value and label" do
      expect(text).to eq("Your code")
    end
  end

  context "with a facts node alone" do
    let(:facts) do
      holder = []
      CommandTower::UI.document(text_fallback: "x") do |d|
        d.stack do |s|
          holder << s.facts do |f|
            f.key_value { |kv| kv.item "When", kv.time(at:, zone: "UTC") }
            f.badge "Paid"
          end
        end
      end
      holder.first
    end

    it "is derivable without its document" do
      expect(described_class.call(facts)).to eq("When: Thu, Dec 4, 2:00 PM UTC\nPaid")
    end
  end

  context "with a label-less key_value row" do
    let(:text) do
      UiSpecHelpers.derive_text do |d|
        d.key_value do |kv|
          kv.item nil, "Mission Street Studio"
          kv.item "Spot", "12"
        end
      end
    end

    it "emits the bare value without a leading colon" do
      expect(text).to eq("Mission Street Studio\nSpot: 12")
    end
  end

  context "with banner, stat tile, divider and image" do
    let(:text) do
      UiSpecHelpers.derive_text do |d|
        d.stack do |s|
          s.banner "Body", title: "Heads up"
          s.stat_tile value: "3", label: "Spots"
          s.divider
          s.image src: "https://example.com/a.png", aspect: 1.0, alt: "A photo"
        end
      end
    end

    it "derives title, body, tile and alt in order" do
      expect(text).to eq("Heads up\nBody\nSpots: 3\nA photo")
    end
  end
end
