# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Inbox, :messaging_inbox do
  let(:user) { create(:user) }
  let!(:item) { create_inbox_for(user:) }
  let(:communication_id) { item.communication_id }
  let(:recipient_id) { user.id }

  describe ".viewed_for_communication?" do
    subject(:viewed) do
      described_class.viewed_for_communication?(
        CommandTower::Messaging::Contract::Requests::ViewedForCommunication.build(communication_id:, recipient_id:)
      )
    end

    it { is_expected.to be(false) }

    context "when the item was viewed" do
      before { item.update!(viewed_at: Time.current) }

      it { is_expected.to be(true) }
    end

    context "when another recipient asks" do
      let(:recipient_id) { create(:user).id }

      it { is_expected.to be_nil }
    end

    context "when the communication is missing" do
      let(:communication_id) { 0 }

      it { is_expected.to be_nil }
    end

    context "when the item is deleted" do
      before { item.update!(deleted_at: Time.current, status: "deleted") }

      it { is_expected.to be_nil }
    end

    context "when the communication is not inbox-backed" do
      let(:communication_id) { create(:messaging_communication, user:).id }

      it { is_expected.to be_nil }
    end

    context "when communication_id is nil" do
      let(:communication_id) { nil }

      it { expect { viewed }.to raise_error(CommandTower::Messaging::Contract::ValidationError) }
    end

    context "when recipient_id is nil" do
      let(:recipient_id) { nil }

      it { expect { viewed }.to raise_error(CommandTower::Messaging::Contract::ValidationError) }
    end

    it "rejects a request of the wrong class" do
      expect { described_class.viewed_for_communication?(Object.new) }.to raise_error(CommandTower::Messaging::Contract::ValidationError)
    end
  end

  describe ".mark_viewed_for_communication" do
    subject(:marked) do
      described_class.mark_viewed_for_communication(
        CommandTower::Messaging::Contract::Requests::MarkViewedForCommunication.build(communication_id:, recipient_id:)
      )
    end

    it "returns an InboxViewMark reporting newly_viewed" do
      expect(marked).to have_attributes(
        communication_id: item.communication_id, inbox_item_id: item.id, viewed: true, newly_viewed: true
      )
    end

    it "persists viewed_at" do
      marked

      expect(item.reload.viewed_at).to be_present
    end

    context "when already marked viewed" do
      before { item.update!(viewed_at: Time.current) }

      it "is idempotent: the second call is not newly_viewed" do
        expect(marked).to have_attributes(viewed: true, newly_viewed: false)
      end
    end

    it "emits no audit event" do
      expect { marked }.not_to change(CommandTower::Audit::Event, :count)
    end

    context "when another recipient asks" do
      let(:recipient_id) { create(:user).id }

      it { is_expected.to be_nil }
    end

    context "when the communication is missing" do
      let(:communication_id) { 0 }

      it { is_expected.to be_nil }
    end

    context "when the communication is not inbox-backed" do
      let(:communication_id) { create(:messaging_communication, user:).id }

      it { is_expected.to be_nil }
    end

    context "when the item is deleted" do
      before { item.update!(deleted_at: Time.current, status: "deleted") }

      it { is_expected.to be_nil }

      it "does not mark it viewed" do
        marked

        expect(item.reload.viewed_at).to be_nil
      end
    end

    context "when communication_id is nil" do
      let(:communication_id) { nil }

      it { expect { marked }.to raise_error(CommandTower::Messaging::Contract::ValidationError) }
    end

    context "when recipient_id is nil" do
      let(:recipient_id) { nil }

      it { expect { marked }.to raise_error(CommandTower::Messaging::Contract::ValidationError) }
    end
  end

  describe "viewed_for_communication? audit" do
    subject(:view_check) do
      lambda do
        described_class.viewed_for_communication?(
          CommandTower::Messaging::Contract::Requests::ViewedForCommunication.build(communication_id:, recipient_id:)
        )
      end
    end

    it "emits no audit event" do
      expect { view_check.call }.not_to change(CommandTower::Audit::Event, :count)
    end
  end

  describe "Messaging::Inbox.mark_viewed newly_viewed" do
    let(:inbox) { CommandTower::Messaging::Inbox }

    it "is true on the first view" do
      expect(inbox.mark_viewed(recipient_id:, inbox_item_id: item.id).newly_viewed).to be(true)
    end

    it "is false on a repeat view" do
      inbox.mark_viewed(recipient_id:, inbox_item_id: item.id)

      expect(inbox.mark_viewed(recipient_id:, inbox_item_id: item.id).newly_viewed).to be(false)
    end

    it "is false for other operations" do
      expect(inbox.archive(recipient_id:, inbox_item_id: item.id).newly_viewed).to be(false)
    end
  end
end
