# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Inbox, :messaging_inbox do
  describe ".resolve_for_event / .unresolve_for_event" do
    let(:user) { create(:user) }
    let!(:item) { create_inbox_for(user:) }
    let(:request_attrs) do
      {
        recipient_id: user.id,
        notification_type_key: item.communication.notification_type_key,
        host_event_identity: "event-1"
      }
    end
    let(:request) { CommandTower::Messaging::Contract::Requests::ResolveForEvent.build(**request_attrs) }

    before { item.communication.update!(host_event_identity: "event-1") }

    context "when resolving an unresolved item" do
      let(:result) { described_class.resolve_for_event(request) }

      it "reports the change", :aggregate_failures do
        expect(result).to have_attributes(
          communication_id: item.communication_id, inbox_item_id: item.id, resolved: true, changed: true
        )
        expect(item.reload.resolved_at).to be_present
      end

      it "never touches viewed_at" do
        result

        expect(item.reload.viewed_at).to be_nil
      end

      it "emits no audit event" do
        expect { described_class.resolve_for_event(request) }.not_to change(CommandTower::Audit::Event, :count)
      end

      it "schedules no job" do
        expect { described_class.resolve_for_event(request) }.not_to have_enqueued_job
      end
    end

    context "when the item is already resolved" do
      before { described_class.resolve_for_event(request) }

      it "is idempotent" do
        expect(described_class.resolve_for_event(request)).to have_attributes(resolved: true, changed: false)
      end

      it "keeps the original resolved_at" do
        expect { described_class.resolve_for_event(request) }.not_to(change { item.reload.resolved_at })
      end

      it "unresolves", :aggregate_failures do
        expect(described_class.unresolve_for_event(request)).to have_attributes(resolved: false, changed: true)
        expect(item.reload.resolved_at).to be_nil
      end

      it "removes the item from the list" do
        expect(CommandTower::Messaging::Inbox.list(recipient_id: user.id).items).to be_empty
      end

      it "removes the item from the unread count" do
        expect(CommandTower::Messaging::Inbox.unread_count(recipient_id: user.id).count).to eq(0)
      end

      it "still lets show open the resolved item" do
        expect(CommandTower::Messaging::Inbox.show(recipient_id: user.id, inbox_item_id: item.id).id).to eq(item.id)
      end
    end

    context "when viewed_at was set before resolving and unresolving" do
      let(:viewed_at) { 2.days.ago.change(usec: 0) }

      before do
        item.update!(viewed_at:)
        described_class.resolve_for_event(request)
        described_class.unresolve_for_event(request)
      end

      it "keeps viewed_at" do
        expect(item.reload.viewed_at).to eq(viewed_at)
      end
    end

    context "when unresolving an unresolved item" do
      it "reports no change" do
        expect(described_class.unresolve_for_event(request)).to have_attributes(resolved: false, changed: false)
      end
    end

    context "with an unknown event" do
      let(:request_attrs) { super().merge(host_event_identity: "nope") }

      it "returns nil" do
        expect(described_class.resolve_for_event(request)).to be_nil
      end
    end

    context "when another recipient asks" do
      let(:other_user) { create(:user) }
      let(:request_attrs) { super().merge(recipient_id: other_user.id) }

      it "returns nil and leaves the item unresolved", :aggregate_failures do
        expect(described_class.resolve_for_event(request)).to be_nil
        expect(item.reload.resolved_at).to be_nil
      end
    end

    context "with a deleted item" do
      before { item.update!(deleted_at: Time.current, status: "deleted") }

      it "returns nil" do
        expect(described_class.resolve_for_event(request)).to be_nil
      end
    end

    context "with a blank notification_type_key" do
      let(:request_attrs) { super().merge(notification_type_key: " ") }

      it "is rejected" do
        expect { described_class.resolve_for_event(request) }
          .to raise_error(CommandTower::Messaging::Contract::ValidationError, /notification_type_key/)
      end
    end

    context "with a blank host_event_identity" do
      let(:request_attrs) { super().merge(host_event_identity: "") }

      it "is rejected" do
        expect { described_class.unresolve_for_event(request) }
          .to raise_error(CommandTower::Messaging::Contract::ValidationError, /host_event_identity/)
      end
    end

    context "with a nil recipient_id" do
      let(:request_attrs) { super().merge(recipient_id: nil) }

      it "is rejected" do
        expect { described_class.resolve_for_event(request) }
          .to raise_error(CommandTower::Messaging::Contract::ValidationError)
      end
    end

    context "with a foreign request object" do
      it "is rejected" do
        expect { described_class.resolve_for_event(Object.new) }
          .to raise_error(CommandTower::Messaging::Contract::ValidationError)
      end
    end
  end
end
