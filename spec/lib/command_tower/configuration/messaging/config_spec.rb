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

  describe "expo composer" do
    around do |example|
      previous_adapter = CommandTower.config.messaging.expo.adapter
      previous_token = CommandTower.config.messaging.expo.access_token
      example.run
    ensure
      CommandTower.config.messaging.expo.adapter = previous_adapter
      CommandTower.config.messaging.expo.access_token = previous_token
    end

    context "with defaults" do
      before do
        CommandTower.config.messaging.expo.adapter = "disabled"
        CommandTower.config.messaging.expo.access_token = ""
      end

      it "defaults adapter to disabled with Expo API base URL and blank optional access_token" do
        expect(CommandTower.config.messaging.expo.adapter).to eq("disabled")
        expect(CommandTower.config.messaging.expo.api_base_url).to eq("https://exp.host/--/api/v2/push")
        expect(CommandTower.config.messaging.expo.timeout_seconds).to eq(5)
        expect(CommandTower.config.messaging.expo.access_token).to eq("")
      end
    end

    %w[disabled fake log http].each do |adapter_name|
      context "when adapter is #{adapter_name}" do
        before { CommandTower.config.messaging.expo.adapter = adapter_name }

        it "accepts #{adapter_name}" do
          expect(CommandTower.config.messaging.expo.adapter).to eq(adapter_name)
        end
      end
    end

    context "when adapter is unknown" do
      subject(:invoke) { CommandTower.config.messaging.expo.adapter = "twilio" }

      it "rejects adapters outside the allow-list" do
        expect { invoke }.to raise_error(ClassComposer::ValidatorError)
      end
    end

    context "when access_token is set" do
      before do
        CommandTower.config.messaging.expo.access_token = "expo-token"
        CommandTower.config.messaging.expo.adapter = "http"
      end

      it "accepts an optional access_token without requiring it for http" do
        expect(CommandTower.config.messaging.expo.access_token).to eq("expo-token")
        expect(CommandTower.config.messaging.expo.adapter).to eq("http")
      end
    end
  end
end
