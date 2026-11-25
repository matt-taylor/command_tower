# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::UsernameWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user, username: "new_name") }

    let(:user) { create(:user, roles: ["member"], username: nil) }

    before do
      allow(CommandTower.config.username).to receive_messages(self_service: true, self_change: false)
    end

    context "when the session is an impersonation overlay" do
      before { CommandTower::Current.impersonation_active = true }

      after { CommandTower::Current.reset }

      it "is forbidden" do
        expect(result.http_status).to eq(:forbidden)
      end

      it "does not set the username" do
        result
        expect(user.reload.username).to be_nil
      end
    end

    context "when the session is a normal session" do
      it "sets the username" do
        expect(result.payload[:username]).to eq("new_name")
      end
    end
  end
end
