# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::ChannelDetectors do
  describe ".email_configured?" do
    subject(:result) { described_class.email_configured? }

    before do
      allow(CommandTower::Messaging::Execution::Adapters::Email::Configuration)
        .to receive(:email_configured?).and_return(configured)
    end

    context "when email transport is configured" do
      let(:configured) { true }

      it { is_expected.to be(true) }
    end

    context "when email transport is not configured" do
      let(:configured) { false }

      it { is_expected.to be(false) }
    end
  end

  describe ".sms_configured?" do
    subject(:result) { described_class.sms_configured? }

    before do
      allow(CommandTower::Messaging::Execution::Adapters::Sms::Configuration)
        .to receive(:sms_configured?).and_return(configured)
    end

    context "when messaging SMS is configured" do
      let(:configured) { true }

      it { is_expected.to be(true) }
    end

    context "when messaging SMS is not configured" do
      let(:configured) { false }

      it { is_expected.to be(false) }
    end
  end

  describe ".pushover_configured?" do
    subject(:result) { described_class.pushover_configured? }

    before do
      allow(CommandTower::Messaging::Execution::Adapters::Pushover::Configuration)
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

  describe ".configured?" do
    subject(:result) { described_class.configured?(channel_key) }

    before do
      allow(described_class).to receive(:email_configured?).and_return(true)
      allow(described_class).to receive(:sms_configured?).and_return(true)
      allow(described_class).to receive(:pushover_configured?).and_return(true)
    end

    context "when channel is inbox" do
      let(:channel_key) { "inbox" }

      it { is_expected.to be(true) }
    end

    context "when channel is email" do
      let(:channel_key) { "email" }

      it { is_expected.to be(true) }
    end

    context "when channel is sms" do
      let(:channel_key) { "sms" }

      it { is_expected.to be(true) }
    end

    context "when channel is pushover" do
      let(:channel_key) { "pushover" }

      it { is_expected.to be(true) }
    end

    context "when channel is push" do
      let(:channel_key) { "push" }

      it { is_expected.to be(false) }
    end

    context "when channel is unknown" do
      let(:channel_key) { "unknown" }

      it { is_expected.to be(false) }
    end
  end

  describe ".sms_product_ready?" do
    subject(:result) { described_class.sms_product_ready? }

    before do
      allow(described_class).to receive(:sms_configured?).and_return(notification_ready)
      allow(CommandTower::Identity::PhoneVerification::SmsConfiguration)
        .to receive(:sms_ready?).and_return(otp_ready)
    end

    [
      { notification: true, otp: true, expected: true },
      { notification: true, otp: false, expected: false },
      { notification: false, otp: true, expected: false },
      { notification: false, otp: false, expected: false }
    ].each do |example|
      context "when notification=#{example[:notification]} and otp=#{example[:otp]}" do
        let(:notification_ready) { example[:notification] }
        let(:otp_ready) { example[:otp] }

        it "returns #{example[:expected]}" do
          expect(result).to eq(example[:expected])
        end
      end
    end
  end
end
