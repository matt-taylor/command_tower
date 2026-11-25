# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::HomeNotices::AcknowledgeWorkflow, :aggregate_failures,
               :defined_render, :messaging_inbox, :messaging_notification_types do
  include HomeNoticeSelectSpecHelpers
  include HomeNoticeMutationSpecHelpers
  include HomeNoticeDeliverySpecHelpers

  let(:user) { create(:user) }
  let(:notice) { delivery_class }
  let!(:item) do
    communication = create(
      :messaging_communication,
      user:, notification_type_key: "defined.render", body: "Check in is open",
      metadata: { "headline" => "Check in is open", "class_name" => "Arms", "door_code" => secret_code },
      metadata_version: 1, slots: { "headline" => "Check in is open" }
    )
    create(:messaging_inbox_item, communication:)
  end
  let!(:row) do
    CommandTower::HomeNotice.create!(
      user:, kind: "delivery", key: notice.key, identity: identity_for(user), communication_id: item.communication_id
    )
  end
  let(:run) { -> { described_class.call(user:, impersonating: false, notice_id: notice_id_for(row.public_id)) } }

  around do |example|
    previous = CommandTower::HomeNotices::Catalog.notices
    example.run
  ensure
    CommandTower::HomeNotices::Catalog.load!(previous)
  end

  before do
    CommandTower::RedisConnection.with(&:flushdb)
    register_definition(definition_class(&class_and_code_fact))
    CommandTower::HomeNotices::Catalog.load!([notice])
  end

  it "acknowledges the notice and marks the inbox item viewed" do
    expect(run.call).to be_success
    expect(row.reload.acknowledged_at).to be_present
    expect(item.reload.viewed_at).to be_present
  end

  context "when the inbox mark fails" do
    before do
      allow(CommandTower::Messaging::Contract::Inbox).to receive(:mark_viewed_for_communication).and_raise("boom")
      allow(CommandTower::Events).to receive(:publish).and_call_original
    end

    it "still acknowledges, and logs it" do
      expect([run.call.success?, row.reload.acknowledged_at.present?]).to eq([true, true])
      expect(CommandTower::Events).to have_received(:publish).with(hash_including(name: "linked_mark_failed"))
    end
  end
end
