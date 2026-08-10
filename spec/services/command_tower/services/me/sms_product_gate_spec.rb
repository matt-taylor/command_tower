# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::SmsProductGate do
  describe ".enabled?" do
    subject(:enabled) { described_class.enabled? }

    before do
      allow(CommandTower::Messaging::ChannelDetectors)
        .to receive(:sms_product_ready?).and_return(ready)
    end

    context "when SMS product dual-gate is ready" do
      let(:ready) { true }

      it { is_expected.to be(true) }
    end

    context "when SMS product dual-gate is not ready" do
      let(:ready) { false }

      it { is_expected.to be(false) }
    end
  end
end
