# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Session::Config do
  subject(:config) { CommandTower.config.session }

  it { expect(config).to be_a(described_class) }
  it { expect(config.idle_timeout).to eq(30.days) }
  it { expect(config.absolute_timeout).to eq(90.days) }
  it { expect(config.last_seen_write_interval).to eq(5.minutes) }
  it { expect(config.enforce).to be(true) }
  it { expect(config.upgrade_legacy_tokens).to be(true) }
end
