# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Preferences::PlatformEnabledChannels do
  after do
    CommandTower.config.messaging.platform_enabled_channels = -> { [] }
  end

  context "when unset" do
    before { CommandTower.config.messaging.platform_enabled_channels = -> { [] } }

    it "defaults to an empty list when unset" do
      expect(described_class.call).to eq([])
    end
  end

  context "with a configured host callable" do
    before { CommandTower.config.messaging.platform_enabled_channels = -> { %w[email sms] } }

    it "invokes the configured host callable" do
      expect(described_class.call).to eq(%w[email sms])
    end
  end

  context "when inspecting source" do
    let(:source) do
      File.read(
        CommandTower::Engine.root.join(
          "app/services/command_tower/services/messaging/preferences/platform_enabled_channels.rb"
        )
      )
    end

    it "does not reference host product constants" do
      expect(source).not_to include("Services::Messaging::PlatformEnabledChannels")
      expect(source).not_to include("doublefloor")
    end
  end
end
