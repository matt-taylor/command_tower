# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::HomeNotices::Config do
  subject(:config) { described_class.new }

  describe "defaults" do
    it { expect(config.enabled).to be(false) }
    it { expect(config.notices).to eq([]) }
    it { expect(config.global_cooldown).to eq(8.hours) }
    it { expect(config.blocking_daily_cap).to eq(2) }
    it { expect(config.max_open_deliveries).to eq(20) }
    it { expect(config.rate_limit_per_minute).to eq(30) }
    it { expect(config.mutation_rate_limit_per_minute).to eq(120) }
    it { expect(config.update_app_campaign).to be(true) }
  end

  it "is reachable as config.home_notices" do
    expect(CommandTower.config.home_notices).to be_a(described_class)
  end

  describe "global_cooldown minimum" do
    it "accepts exactly 1 hour" do
      config.global_cooldown = 1.hour
      expect(config.validate!).to eq(config)
    end

    it "rejects less than 1 hour when set" do
      expect { config.global_cooldown = 30.minutes }.to raise_error(StandardError, /at least 1 hour/)
    end
  end
end
