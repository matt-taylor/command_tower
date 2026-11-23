# frozen_string_literal: true

RSpec.describe CommandTower::UI::Hostname do
  {
    "Images.Example.COM" => "images.example.com",
    " cdn.example.com. " => "cdn.example.com",
    "bücher.example" => "xn--bcher-kva.example",
    "münchen.de" => "xn--mnchen-3ya.de",
    "例え.jp" => "xn--r8jz45g.jp"
  }.each do |input, expected|
    it "normalizes #{input.inspect}" do
      expect(described_class.normalize(input)).to eq(expected)
    end
  end

  [
    nil, "", "https://example.com", "example.com:8080", "example.com/path", "user@example.com",
    "*.example.com", "exa mple.com", "-bad.example.com", "a..b", 12
  ].each do |input|
    it "rejects #{input.inspect}" do
      expect(described_class.normalize(input)).to be_nil
    end
  end
end
