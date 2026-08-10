# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Pushover::Configuration do
  around do |example|
    previous = CommandTower.config.messaging.pushover.adapter
    example.run
  ensure
    CommandTower.config.messaging.pushover.adapter = previous
  end

  %w[fake log http].each do |adapter_name|
    context "with the #{adapter_name} adapter" do
      before { CommandTower.config.messaging.pushover.adapter = adapter_name }

      it "is configured" do
        expect(described_class.pushover_configured?).to be(true)
      end
    end
  end

  context "when disabled" do
    before { CommandTower.config.messaging.pushover.adapter = "disabled" }

    it "is not configured when disabled" do
      expect(described_class.pushover_configured?).to be(false)
    end
  end
end
