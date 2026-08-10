# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::PushoverProductGate do
  describe ".enabled?" do
    subject(:enabled) { described_class.enabled? }

    before do
      allow(CommandTower::Messaging::ChannelDetectors)
        .to receive(:pushover_configured?).and_return(configured)
    end

    context "when Pushover is configured" do
      let(:configured) { true }

      it { is_expected.to be(true) }
    end

    context "when Pushover is not configured" do
      let(:configured) { false }

      it { is_expected.to be(false) }
    end
  end
end
