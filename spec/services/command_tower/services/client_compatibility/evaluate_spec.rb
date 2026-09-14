# frozen_string_literal: true

RSpec.describe CommandTower::Services::ClientCompatibility::Evaluate do
  let(:registry) { CommandTower::Configuration::Registry::ClientCompatibility::Config.new }
  # "session" is a real registered RBAC entity (CommandTower::Auth::SessionController#show),
  # used here only to exercise entity-matching without inventing test-only RBAC state.
  let(:controller_class) { CommandTower::Auth::SessionController }
  let(:action_name) { "show" }

  subject(:decision) do
    described_class.call(
      app_version_header: app_version_header,
      platform_header: platform_header,
      controller_class: controller_class,
      action_name: action_name,
      registry: registry
    )
  end

  context "when the registry is completely untouched" do
    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "web" }

    it "is a no-op compatible decision" do
      expect(decision.decision).to eq(:compatible)
    end
  end

  context "when the platform header is missing" do
    before { registry.platform(:web) { |p| p.minimum = "1.0.0" } }

    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "" }

    it "is identity_invalid" do
      expect(decision.decision).to eq(:identity_invalid)
      expect(decision.scope).to eq(:application)
    end
  end

  context "when the app version header is malformed (partial)" do
    before { registry.platform(:web) { |p| p.minimum = "1.0.0" } }

    let(:app_version_header) { "1.2" }
    let(:platform_header) { "web" }

    it "is identity_invalid, not a loose Gem::Version comparison" do
      expect(decision.decision).to eq(:identity_invalid)
    end
  end

  context "when the platform is recognized but not configured by the host" do
    before { registry.platform(:web) { |p| p.minimum = "1.0.0" } }

    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "android" }

    it "is identity_invalid with application scope" do
      expect(decision.decision).to eq(:identity_invalid)
      expect(decision.scope).to eq(:application)
      expect(decision.platform).to eq(:android)
    end
  end

  context "when current version is below the platform-global minimum" do
    before { registry.platform(:web) { |p| p.minimum = "2.0.0" } }

    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "web" }

    it "is incompatible with application scope" do
      expect(decision.decision).to eq(:incompatible)
      expect(decision.scope).to eq(:application)
      expect(decision.effective_minimum).to eq("2.0.0")
      expect(decision.recommendation_projection).to be_nil
    end
  end

  context "when current version meets the platform-global minimum with no recommended configured" do
    before { registry.platform(:web) { |p| p.minimum = "1.0.0" } }

    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "web" }

    it "is compatible and still returns a projection without a recommendedVersion" do
      expect(decision.decision).to eq(:compatible)
      expect(decision.recommendation_projection).to include(platform: "web", currentVersion: "1.0.0", minimumVersion: "1.0.0", updateAvailable: false)
      expect(decision.recommendation_projection).not_to have_key(:recommendedVersion)
    end
  end

  context "when current version is below the platform recommended version" do
    before do
      registry.platform(:web) do |p|
        p.minimum = "1.0.0"
        p.recommended = "1.5.0"
      end
    end

    let(:app_version_header) { "1.2.0" }
    let(:platform_header) { "web" }

    it "is recommended with updateAvailable true" do
      expect(decision.decision).to eq(:recommended)
      expect(decision.recommendation_projection).to include(
        recommendedVersion: "1.5.0",
        updateAvailable: true
      )
    end
  end

  context "when a matched entity has a stricter direct minimum than the platform-global floor" do
    before do
      registry.platform(:web) { |p| p.minimum = "1.0.0" }
      registry.entity("session") { |e| e.minimum.web = "1.5.0" }
    end

    let(:app_version_header) { "1.2.0" }
    let(:platform_header) { "web" }

    it "is incompatible with capability scope at the strictest minimum" do
      expect(decision.decision).to eq(:incompatible)
      expect(decision.scope).to eq(:capability)
      expect(decision.effective_minimum).to eq("1.5.0")
      expect(decision.matched_entity_names).to include("session")
    end
  end

  context "when a matched entity requirement resolves via a bound client contract" do
    before do
      registry.client_contract("account.audit.v2")
      registry.bind("account.audit.v2") { |b| b.web = "1.6.0" }
      registry.platform(:web) { |p| p.minimum = "1.0.0" }
      registry.entity("session") { |e| e.client_contract = "account.audit.v2" }
    end

    let(:app_version_header) { "1.2.0" }
    let(:platform_header) { "web" }

    it "uses the bound contract version as the entity floor" do
      expect(decision.decision).to eq(:incompatible)
      expect(decision.effective_minimum).to eq("1.6.0")
    end
  end

  context "when the matched entity floor does not exceed the platform-global floor" do
    before do
      registry.platform(:web) { |p| p.minimum = "1.5.0" }
      registry.entity("session") { |e| e.minimum.web = "1.0.0" }
    end

    let(:app_version_header) { "1.5.0" }
    let(:platform_header) { "web" }

    it "keeps application scope (platform-global remains strictest)" do
      expect(decision.decision).to eq(:compatible)
      expect(decision.scope).to eq(:application)
      expect(decision.effective_minimum).to eq("1.5.0")
    end
  end

  context "on a native platform" do
    before do
      registry.platform(:ios) do |p|
        p.minimum = "2.0.0"
        p.update_url = "https://apps.apple.com/app/id123"
      end
    end

    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "ios" }

    it "reports app_store recovery with the configured update url" do
      expect(decision.recovery).to eq(:app_store)
      expect(decision.update_url).to eq("https://apps.apple.com/app/id123")
    end
  end

  describe "determinism" do
    before { registry.platform(:web) { |p| p.minimum = "1.0.0" } }

    let(:app_version_header) { "1.0.0" }
    let(:platform_header) { "web" }

    let(:repeated_decision) do
      described_class.call(
        app_version_header: app_version_header,
        platform_header: platform_header,
        controller_class: controller_class,
        action_name: action_name,
        registry: registry
      )
    end

    it "returns an equivalent decision for identical inputs" do
      expect(decision.decision).to eq(repeated_decision.decision)
    end

    it "returns the same effective minimum for identical inputs" do
      expect(decision.effective_minimum).to eq(repeated_decision.effective_minimum)
    end

    it "does not mutate CommandTower::Current" do
      expect { decision }.not_to change { CommandTower::Current.client_compatibility_recommendation }
    end
  end
end
