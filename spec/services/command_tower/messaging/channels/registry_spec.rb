# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Channels do
  describe "registry presentation metadata" do
    let(:push) { described_class.fetch!("push") }

    it "exposes Push catalog fields for INS-2" do
      expect(push.label).to eq("Push")
      expect(push.glyph_key).to eq("bell")
      expect(push.order).to eq(3)
      expect(push.description).to eq("Alerts on this device")
    end
  end
end
