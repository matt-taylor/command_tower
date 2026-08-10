# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Username::Check do
  subject(:check) { described_class.new }

  it "is enabled by default so Engine exposes GET /auth/username/availability" do
    expect(check.enable).to be(true)
    expect(CommandTower.config.username.realtime_username_check?).to be(true)
  end
end
