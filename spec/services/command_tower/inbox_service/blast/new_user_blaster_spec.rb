# frozen_string_literal: true

RSpec.describe CommandTower::InboxService::Blast::NewUserBlaster do
  before do
    create_list(:message_blast, new_users_count, new_users: true)
    create_list(:message_blast, count, new_users: false)
  end

  let(:count) { 5 }
  let(:new_users_count) { 5 }
  let(:user) { create(:user) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it "adds correct new user blasts" do
      expect(MessageBlast.count).to eq(count + new_users_count)
    end

    it "sends new user message only" do
      expect { call } .to change { user.reload.messages.count }.by(new_users_count)
    end

    it "succeeds" do
      expect(call.success?).to be(true)
    end
  end
end
