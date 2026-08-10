# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Messaging::Config do
  around do |example|
    previous = CommandTower.config.messaging.allow_fake_adapter
    example.run
  ensure
    CommandTower.config.messaging.allow_fake_adapter = previous
  end

  context "with the default value" do
    before { CommandTower.config.messaging.allow_fake_adapter = false }

    it "defaults allow_fake_adapter to false (fail-closed platform testing flag)" do
      expect(CommandTower.config.messaging.allow_fake_adapter).to be(false)
    end
  end

  context "when setting true" do
    before { CommandTower.config.messaging.allow_fake_adapter = true }

    it "accepts true for allow_fake_adapter" do
      expect(CommandTower.config.messaging.allow_fake_adapter).to be(true)
    end
  end

  context "when setting false explicitly" do
    before { CommandTower.config.messaging.allow_fake_adapter = false }

    it "accepts false for allow_fake_adapter" do
      expect(CommandTower.config.messaging.allow_fake_adapter).to be(false)
    end
  end

  context "with a non-boolean value" do
    subject(:invoke) { CommandTower.config.messaging.allow_fake_adapter = "true" }

    it "rejects non-boolean allow_fake_adapter values at configure time" do
      expect { invoke }.to raise_error(ClassComposer::ValidatorError, /TrueClass, FalseClass/)
    end
  end
end
