# frozen_string_literal: true

RSpec.describe CommandTower::UI::TimeFormatter do
  let(:instant) { "2025-12-04T14:00:00Z" }

  it "ships the 21 timeCases rows" do
    expect(CommandTower::UI::Tokens.mapping.fetch("timeCases").size).to eq(21)
  end

  it "gives every timeCases row its five fields" do
    expect(CommandTower::UI::Tokens.mapping.fetch("timeCases"))
      .to all(include("at", "zone", "format", "label", "expected"))
  end

  CommandTower::UI::Tokens.mapping.fetch("timeCases").each do |row|
    it "renders #{row['expected'].inspect} for #{row['at']} in #{row['zone']} (#{row['format']}, #{row['label']})" do
      expect(described_class.call(at: row["at"], zone: row["zone"], format: row["format"], label: row["label"]))
        .to eq(row["expected"])
    end
  end

  describe "zone user" do
    UiSpecHelpers.wire_hardening.dig("userZone", "cases").each do |row|
      it "renders #{row['expected'].inspect} for zone #{row['zone']} with user zone #{row['userZone']}" do
        expect(described_class.call(at: row["at"], zone: row["zone"], format: row["format"], label: row["label"],
                                    user_zone: row["userZone"])).to eq(row["expected"])
      end
    end

    it "accepts the :user symbol" do
      expect(described_class.call(at: instant, zone: :user, format: :time, user_zone: "America/New_York"))
        .to eq("9:00 AM ET")
    end

    context "with a configured default zone" do
      before { allow(CommandTower.config.ui).to receive(:default_zone).and_return("America/Los_Angeles") }

      it "defaults user_zone to config.ui.default_zone" do
        expect(described_class.call(at: instant, zone: "user", format: :time)).to eq("6:00 AM PT")
      end
    end
  end

  it "accepts a Time instant" do
    expect(described_class.call(at: Time.utc(2025, 12, 4, 14), zone: "America/Los_Angeles", format: :short))
      .to eq("Thu, Dec 4, 6:00 AM PT")
  end

  it "labels :auto on the server" do
    expect(described_class.call(at: instant, zone: "America/New_York", format: :time)).to eq("9:00 AM ET")
  end

  it "renders :countdown as :short" do
    expect(described_class.call(at: instant, zone: "America/Los_Angeles", format: :countdown))
      .to eq("Thu, Dec 4, 6:00 AM PT")
  end

  it "never labels :date" do
    expect(described_class.call(at: instant, zone: "UTC", format: :date, label: :always)).to eq("Thu, Dec 4")
  end

  it "uses only plain U+0020 spaces" do
    expect(described_class.call(at: instant, zone: "UTC", format: :long)).not_to match(/[    ]/)
  end

  it "rejects unknown formats" do
    expect { described_class.call(at: instant, zone: "UTC", format: :nope) }.to raise_error(ArgumentError)
  end

  it "rejects unknown labels" do
    expect { described_class.call(at: instant, zone: "UTC", format: :time, label: :nope) }
      .to raise_error(ArgumentError)
  end
end
