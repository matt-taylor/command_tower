# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::Capabilities do
  describe ".project" do
    subject(:project) { described_class.project(user) }

    let(:user) { create(:user, email_validated: true) }

    before do
      allow(CommandTower::Messaging::ChannelDetectors)
        .to receive(:sms_product_ready?).and_return(false)
      allow(CommandTower::Messaging::ChannelDetectors)
        .to receive(:pushover_configured?).and_return(false)
    end

    it "returns the self-service capability flags" do
      expect(project).to eq(
        editName: { enabled: true },
        editUsername: { enabled: false },
        changeEmail: { enabled: false },
        changePassword: { enabled: true },
        deleteAccount: { enabled: true },
        editPhone: { enabled: false },
        editPushover: { enabled: false },
        logoutAllDevices: { enabled: false },
        verifyEmail: { enabled: false }
      )
    end

    context "when SMS product is ready" do
      before do
        allow(CommandTower::Messaging::ChannelDetectors)
          .to receive(:sms_product_ready?).and_return(true)
      end

      it "enables editPhone" do
        expect(project[:editPhone]).to eq(enabled: true)
      end
    end

    context "when Pushover is configured" do
      before do
        allow(CommandTower::Messaging::ChannelDetectors)
          .to receive(:pushover_configured?).and_return(true)
      end

      it "enables editPushover" do
        expect(project[:editPushover]).to eq(enabled: true)
      end
    end

    context "when the email is unverified" do
      let(:user) { create(:user, :unvalidated_email) }

      it "enables verifyEmail" do
        expect(project[:verifyEmail]).to eq(enabled: true)
      end
    end
  end
end
