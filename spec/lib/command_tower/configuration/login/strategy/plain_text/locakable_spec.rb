# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Login::Strategy::PlainText::Locakable do
  before { allow(described_class).to receive(:warn_deprecated) }

  it "logs a deprecation when enabled" do
    described_class.new.enable = true

    expect(described_class).to have_received(:warn_deprecated)
  end

  it "stays quiet when left disabled" do
    described_class.new.enable = false

    expect(described_class).not_to have_received(:warn_deprecated)
  end
end
