# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::Compose,
               :defined_render, :messaging_inbox, :messaging_notification_types do
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
  let(:record) do
    CommandTower::HomeNotices::NoticeRecord.from(
      CommandTower::HomeNotice.create!(
        user:, kind: "delivery", key: notice.key, identity: "x/#{user.id}", communication_id: item.communication_id
      )
    )
  end
  let(:result) { compose_linked(notice, user:, record:) }

  before { register_definition(definition_class(&class_and_code_fact)) }

  it "uses the inbox item's document and hashes it", :aggregate_failures do
    expect(result).to be_success
    expect(result.data[:document]).to be_a(CommandTower::UI::Document)
    expect(result.data[:document].as_json.to_json).to include(secret_code)
    expect(result.data[:content_hash]).to match(/\A\h{64}\z/)
  end

  it "redacts code values when impersonating" do
    expect(compose_linked(notice, user:, record:, impersonating: true).data[:document].as_json.to_json)
      .not_to include(secret_code)
  end

  context "when the host compose would raise" do
    before do
      allow(notice).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap do |instance|
          allow(instance).to receive(:compose).and_raise("host compose must not run")
        end
      end
    end

    it "never calls the host compose" do
      expect(result.data[:document]).to be_present
    end
  end

  [
    ["deleted", { deleted_at: Time.current, status: "deleted" }],
    ["archived", { archived_at: Time.current, status: "archived" }]
  ].each do |label, attributes|
    context "when the inbox item is #{label}" do
      before { item.update!(attributes) }

      it "returns no document and no hash", :aggregate_failures do
        expect(result).to be_success
        expect(result.data[:document]).to be_nil
        expect(result.data[:content_hash]).to be_nil
      end
    end
  end

  context "with no linked communication" do
    let(:record) { nil }

    it("returns no document") { expect(result.data[:document]).to be_nil }
  end
end
