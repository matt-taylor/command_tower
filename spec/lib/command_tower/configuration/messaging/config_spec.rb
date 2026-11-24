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

  describe "sounds composer" do
    around do |example|
      previous = CommandTower.config.messaging.sounds
      example.run
    ensure
      CommandTower.config.messaging.sounds = previous
    end

    context "with the default value" do
      before { CommandTower.config.messaging.sounds = [] }

      it "defaults to no host sounds" do
        expect(CommandTower.config.messaging.sounds).to eq([])
      end
    end

    context "with a non-array value" do
      subject(:invoke) { CommandTower.config.messaging.sounds = "chime" }

      it "rejects it at configure time" do
        expect { invoke }.to raise_error(ClassComposer::ValidatorError)
      end
    end
  end

  describe "compliance composer" do
    let(:compliance) { CommandTower.config.messaging.compliance }

    around do |example|
      previous = {
        api_base_url: compliance.api_base_url,
        preferences_path: compliance.preferences_path,
        postal_address: compliance.postal_address,
        unsubscribe_secret: compliance.unsubscribe_secret
      }
      example.run
    ensure
      previous.each { |name, value| compliance.public_send(:"#{name}=", value) }
    end

    context "with a fresh composer" do
      subject(:fresh) { CommandTower::Configuration::Messaging::Compliance.new }

      it "defaults preferences_path, postal_address and unsubscribe_secret to nil", :aggregate_failures do
        expect(fresh.preferences_path).to be_nil
        expect(fresh.postal_address).to be_nil
        expect(fresh.unsubscribe_secret).to be_nil
      end
    end

    context "when assigning strings" do
      before do
        compliance.api_base_url = "https://api.example.test"
        compliance.postal_address = "1 Example Way"
      end

      it "accepts them", :aggregate_failures do
        expect(compliance.api_base_url).to eq("https://api.example.test")
        expect(compliance.postal_address).to eq("1 Example Way")
      end
    end

    context "when api_base_url is unset and the ENV var is present" do
      before do
        compliance.api_base_url = nil
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("COMMAND_TOWER_API_BASE_URL").and_return("https://env.example.test")
      end

      it "falls back to ENV COMMAND_TOWER_API_BASE_URL" do
        expect(compliance.api_base_url).to eq("https://env.example.test")
      end
    end

    it "rejects a non-string value" do
      expect { compliance.postal_address = 5 }.to raise_error(ClassComposer::ValidatorError)
    end
  end

  describe "strict_definitions composer" do
    around do |example|
      previous = CommandTower.config.messaging.strict_definitions
      example.run
    ensure
      CommandTower.config.messaging.strict_definitions = previous
    end

    it "is true outside production (test env)" do
      expect(CommandTower.config.messaging.strict_definitions).to be(true)
    end

    context "when set to false" do
      before { CommandTower.config.messaging.strict_definitions = false }

      it "accepts false" do
        expect(CommandTower.config.messaging.strict_definitions).to be(false)
      end
    end

    it "rejects a non-boolean" do
      expect { CommandTower.config.messaging.strict_definitions = "yes" }
        .to raise_error(ClassComposer::ValidatorError)
    end
  end

  describe "expo composer" do
    around do |example|
      previous_adapter = CommandTower.config.messaging.expo.adapter
      previous_token = CommandTower.config.messaging.expo.access_token
      previous_home = CommandTower.config.messaging.expo.home_deep_link
      previous_self_test = CommandTower.config.messaging.expo.self_test_deep_link
      previous_levels = CommandTower.config.messaging.expo.interruption_levels
      example.run
    ensure
      CommandTower.config.messaging.expo.interruption_levels = previous_levels
      CommandTower.config.messaging.expo.adapter = previous_adapter
      CommandTower.config.messaging.expo.access_token = previous_token
      CommandTower.config.messaging.expo.home_deep_link = previous_home
      CommandTower.config.messaging.expo.self_test_deep_link = previous_self_test
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
        expect(CommandTower.config.messaging.expo.home_deep_link).to be_nil
        expect(CommandTower.config.messaging.expo.self_test_deep_link).to be_nil
        expect(CommandTower.config.messaging.expo.home_deep_link_configured?).to be(false)
      end
    end

    it "keeps the Expo interruption levels in step with the declaration urgency levels" do
      expect(CommandTower::Configuration::Messaging::Expo::INTERRUPTION_LEVELS)
        .to eq(CommandTower::Messaging::NotificationTypes::URGENCY_LEVELS)
    end

    context "with the default interruption levels" do
      before { CommandTower.config.messaging.expo.interruption_levels = ["normal"] }

      it "supports Normal only" do
        expect(CommandTower.config.messaging.expo.interruption_levels).to eq(["normal"])
      end
    end

    context "when interruption_levels names valid levels" do
      before { CommandTower.config.messaging.expo.interruption_levels = %w[normal time_sensitive] }

      it "accepts them" do
        expect(CommandTower.config.messaging.expo.interruption_levels).to eq(%w[normal time_sensitive])
      end
    end

    context "when interruption_levels names an unknown level" do
      subject(:invoke) { CommandTower.config.messaging.expo.interruption_levels = %w[normal loud] }

      it "rejects it at configure time" do
        expect { invoke }.to raise_error(ClassComposer::ValidatorError)
      end
    end

    context "when interruption_levels is not an array" do
      subject(:invoke) { CommandTower.config.messaging.expo.interruption_levels = "time_sensitive" }

      it "rejects it at configure time" do
        expect { invoke }.to raise_error(ClassComposer::ValidatorError)
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

    context "when home_deep_link is a callable" do
      let(:home_calls) { [] }

      before do
        CommandTower.config.messaging.expo.home_deep_link = lambda {
          home_calls << "pickem://home"
          "pickem://home"
        }
      end

      it "counts as configured without calling it, and resolves only on demand" do
        expect(CommandTower.config.messaging.expo.home_deep_link_configured?).to be(true)
        expect(home_calls).to be_empty
        expect(CommandTower.config.messaging.expo.resolve_home_deep_link).to eq("pickem://home")
        expect(home_calls).to eq(["pickem://home"])
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
