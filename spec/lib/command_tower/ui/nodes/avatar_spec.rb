# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Avatar, :aggregate_failures do
  let(:hosts) { UiSpecHelpers.wire_hardening["images"]["hosts"] }

  before { allow(CommandTower.config.ui).to receive(:image_hosts).and_return(hosts) }

  it "serializes initials" do
    expect(described_class.new(initials: "MT", size: :lg).as_json)
      .to eq("type" => "avatar", "initials" => "MT", "size" => "lg")
  end

  it "serializes an image avatar" do
    expect(described_class.new(src: "https://img.example.com/me.png", alt: "Matt").as_json).to eq(
      "type" => "avatar", "src" => "https://img.example.com/me.png", "size" => "md", "alt" => "Matt"
    )
  end

  CommandTower::UI::Tokens::AVATAR_SIZE.each do |size|
    it "accepts size #{size}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(initials: "A", size: size))).to eq([])
    end
  end

  it "needs src or initials" do
    expect(UiSpecHelpers.error_pairs(described_class.new)).to eq([%i[base src_or_initials_required]])
  end

  it "requires alt with src" do
    expect(UiSpecHelpers.error_pairs(described_class.new(src: "https://img.example.com/me.png")))
      .to eq([%i[alt blank]])
  end

  it "applies the image host allowlist" do
    expect(UiSpecHelpers.error_pairs(described_class.new(src: "https://evil.example.org/me.png", alt: "x")))
      .to eq([%i[src host_not_allowed]])
  end

  it "rejects unknown sizes and long initials" do
    expect(UiSpecHelpers.error_pairs(described_class.new(initials: "ABCD", size: "xl")))
      .to contain_exactly(%i[size inclusion], %i[initials too_long])
  end
end
