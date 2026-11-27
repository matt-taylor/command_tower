# frozen_string_literal: true

RSpec.describe "Me inbox impersonation policy", :messaging_inbox, :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let!(:item) { create_inbox_for(user:) }
  let(:impersonation_headers) do
    operator = create(:user, :role_impersonation_operator)
    session = create(
      :impersonation_session,
      actor: operator, target: user, idle_expires_at: 2.minutes.from_now, absolute_expires_at: 1.hour.from_now
    )
    authenticate_impersonation_with_bearer!(operator, session)
  end

  describe "policy table" do
    let(:routed_actions) do
      CommandTower::Engine.routes.routes.map(&:defaults)
                          .select { |defaults| defaults[:controller] == "command_tower/me/inbox" }
                          .pluck(:action).map(&:to_sym).uniq
    end

    it "routes at least one inbox action" do
      expect(routed_actions).not_to be_empty
    end

    it "has a policy entry for every routed inbox action" do
      expect(CommandTower::Me::InboxController::IMPERSONATION_POLICY.keys).to match_array(routed_actions)
    end

    it "only uses known policy values" do
      expect(CommandTower::Me::InboxController::IMPERSONATION_POLICY.values.uniq)
        .to all(satisfy { |value| %i[passive_skip allow_audited refuse].include?(value) })
    end
  end

  describe "DELETE /me/inbox/:id while impersonating" do
    before { delete "/me/inbox/#{item.id}", headers: impersonation_headers, as: :json }

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(response.parsed_body.dig("errors", 0, "code")).to eq("inbox_impersonation_forbidden") }
    it { expect(item.reload.deleted_at).to be_nil }

    it "writes the contract fixture" do
      write_inbox_contract_fixture("impersonation_forbidden", response)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /me/inbox/bulk/delete while impersonating" do
    before { post "/me/inbox/bulk/delete", params: { ids: [item.id] }, headers: impersonation_headers, as: :json }

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(response.parsed_body.dig("errors", 0, "code")).to eq("inbox_impersonation_forbidden") }
    it { expect(item.reload.deleted_at).to be_nil }
  end

  describe "audit while impersonating", :aggregate_failures do
    let(:events) { CommandTower::Audit::Event.where(action: "messaging_inbox_changed_while_impersonating") }
    let!(:second_item) { create_inbox_for(user:) }

    context "with an archive" do
      before { patch "/me/inbox/#{item.id}/archive", headers: impersonation_headers, as: :json }

      it "writes one event attributed to the operator" do
        expect(response).to have_http_status(:ok)
        expect(events.count).to eq(1)
        expect(events.first).to have_attributes(attribution_mode: "impersonation", affected_user_id: user.id)
        expect(events.first.originating_administrator_id).to be_present
      end

      it "records ids only" do
        expect(events.first.metadata).to include(
          "action" => "archive", "inbox_item_ids" => [item.id], "changed_count" => 1
        )
      end
    end

    it "writes exactly one event for a bulk request" do
      post "/me/inbox/bulk/read", params: { ids: [item.id, second_item.id] }, headers: impersonation_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(events.count).to eq(1)
      expect(events.first.metadata).to include("changed_count" => 2, "inbox_item_ids" => [item.id, second_item.id])
    end

    it "writes one event with the watermark for mark all read" do
      post "/me/inbox/mark-all-read", params: { up_to: second_item.id }, headers: impersonation_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(events.count).to eq(1)
      expect(events.first.metadata).to include("action" => "mark_all_read", "up_to" => second_item.id)
    end

    context "with a capped id list" do
      before do
        stub_const("CommandTower::Messaging::Inbox::ImpersonationAudit::MAX_AUDITED_IDS", 1)
        post "/me/inbox/bulk/read", params: { ids: [item.id, second_item.id] }, headers: impersonation_headers,
                                    as: :json
      end

      it "caps the id list and flags truncation" do
        expect(events.first.metadata).to include("changed_count" => 2, "truncated" => true)
        expect(events.first.metadata["inbox_item_ids"].size).to eq(1)
      end
    end

    context "when nothing changed" do
      before do
        item.update!(archived_at: Time.current, status: CommandTower::Messaging::InboxItem::STATUS_ARCHIVED)
        patch "/me/inbox/#{item.id}/archive", headers: impersonation_headers, as: :json
      end

      it "writes no event" do
        expect(events.count).to eq(0)
      end
    end

    context "when the audit fails" do
      before do
        allow(CommandTower::Audit::Emit).to receive(:call).and_raise(CommandTower::Audit::InvalidPayloadError, "boom")
        patch "/me/inbox/#{item.id}/archive", headers: impersonation_headers, as: :json
      end

      it "rolls the change back" do
        expect(response).not_to have_http_status(:ok)
        expect(item.reload.archived_at).to be_nil
      end
    end

    it "writes no event without impersonating" do
      patch "/me/inbox/#{item.id}/archive", headers: authenticate_request_with_bearer!(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(events.count).to eq(0)
    end
  end

  describe "DELETE /me/inbox/:id without impersonating" do
    before { delete "/me/inbox/#{item.id}", headers: authenticate_request_with_bearer!(user), as: :json }

    it { expect(response).to have_http_status(:ok) }
    it { expect(item.reload.deleted_at).to be_present }
  end
end
