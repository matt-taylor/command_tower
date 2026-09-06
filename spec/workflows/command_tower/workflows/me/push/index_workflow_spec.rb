# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::Push::IndexWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user) }

    let(:user) { create(:user, roles: ["member"]) }

    before do
      allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(true)
    end

    context "when push product gate is off" do
      before do
        allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(false)
      end

      it "returns capability unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
      end
    end

    context "when no endpoints exist" do
      it "returns an empty endpoints collection" do
        expect(result).to be_success
        expect(result.payload[:endpoints]).to eq([])
      end
    end
  end
end
