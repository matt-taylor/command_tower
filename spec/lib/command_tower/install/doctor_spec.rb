# frozen_string_literal: true

RSpec.describe CommandTower::Install::Doctor do
  let(:host_root) { Dir.mktmpdir("ct-doctor-host") }

  after { FileUtils.rm_rf(host_root) }

  let(:with_installed_migrations) do
    lambda do |count: CommandTower::Install::Baseline::ENGINE_MIGRATION_BASENAMES.size|
      migrate = File.join(host_root, "db", "migrate")
      FileUtils.mkdir_p(migrate)
      count.times do |i|
        File.write(File.join(migrate, "2026080500000#{i + 1}_example.command_tower.rb"), "# probe\n")
      end
    end
  end

  context "when host migrations are missing" do
    subject(:findings) { described_class.new(host_root: host_root, env: "test").run }

    it "fails when host migrations are missing" do
      expect(findings.find { |f| f.code == :host_migrations }.severity).to eq(:fail)
    end
  end

  context "when enough command_tower copies exist" do
    before { with_installed_migrations.call }

    subject(:findings) { described_class.new(host_root: host_root, env: "test").run }

    it "passes host migration check when enough command_tower copies exist" do
      expect(findings.find { |f| f.code == :host_migrations }.severity).to eq(:pass)
    end
  end

  context "when JWT secret is the insecure default in production" do
    let(:config) { CommandTower::Configuration::Config.new }

    before { config.jwt.hmac_secret = described_class::INSECURE_JWT_DEFAULT }

    subject(:findings) { described_class.new(host_root: host_root, config: config, env: "production").run }

    it "fails production when JWT secret is the insecure default" do
      expect(findings.find { |f| f.code == :jwt_secret }.severity).to eq(:fail)
      expect(findings.find { |f| f.code == :jwt_secret }.remediation).to include("SECRET_KEY_BASE")
    end
  end

  context "when messaging adapters are unsupported" do
    let(:config) { CommandTower::Configuration::Config.new }

    before do
      allow(config.messaging.sms).to receive(:adapter).and_return("not-a-real-adapter")
      allow(config.messaging.pushover).to receive(:adapter).and_return("also-bad")
      with_installed_migrations.call
    end

    subject(:findings) { described_class.new(host_root: host_root, config: config, env: "test").run }

    it "warns on unsupported messaging adapters" do
      expect(findings.find { |f| f.code == :sms_adapter }.severity).to eq(:warn)
      expect(findings.find { |f| f.code == :pushover_adapter }.severity).to eq(:warn)
    end
  end
end
