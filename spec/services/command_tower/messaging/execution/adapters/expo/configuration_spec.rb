# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Expo::Configuration do
  around do |example|
    previous_adapter = CommandTower.config.messaging.expo.adapter
    previous_token = CommandTower.config.messaging.expo.access_token
    example.run
  ensure
    CommandTower.config.messaging.expo.adapter = previous_adapter
    CommandTower.config.messaging.expo.access_token = previous_token
  end

  %w[fake log http].each do |adapter_name|
    context "with the #{adapter_name} adapter" do
      before { CommandTower.config.messaging.expo.adapter = adapter_name }

      it "is configured" do
        expect(described_class.expo_configured?).to be(true)
      end
    end
  end

  context "when http adapter has a blank access_token" do
    before do
      CommandTower.config.messaging.expo.adapter = "http"
      CommandTower.config.messaging.expo.access_token = ""
    end

    it "is configured without requiring access_token" do
      expect(described_class.expo_configured?).to be(true)
      expect(described_class.new.access_token).to eq("")
    end
  end

  context "when disabled" do
    before { CommandTower.config.messaging.expo.adapter = "disabled" }

    it "is not configured when disabled" do
      expect(described_class.expo_configured?).to be(false)
    end
  end
end
