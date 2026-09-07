# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Application::Config do
  describe "#host_key" do
    around do |example|
      previous = CommandTower.config.application.host_key
      example.run
    ensure
      CommandTower.config.application.host_key = previous
    end

    it "defaults to a blank string on a fresh composer instance" do
      expect(described_class.new.host_key).to eq("")
    end

    context "when overridden" do
      before { CommandTower.config.application.host_key = "pickem" }

      it "accepts an explicit override" do
        expect(CommandTower.config.application.host_key).to eq("pickem")
      end
    end
  end
end
