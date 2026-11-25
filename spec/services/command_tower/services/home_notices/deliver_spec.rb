# frozen_string_literal: true

RSpec.describe CommandTower::Services::HomeNotices::Deliver,
               :defined_render, :messaging_inbox, :messaging_notification_types do
  include HomeNoticeDeliverySpecHelpers

  let(:user) { create(:user) }
  let(:communication_id) { item.communication_id }
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
  let(:result) { deliver(user:, notice:, communication_id:, ends_at: 2.days.from_now, metadata: { "class_id" => 1 }) }

  before { register_definition(definition_class(&class_and_code_fact)) }

  describe "a linked delivery" do
    it "writes the row", :aggregate_failures do
      expect(result.data).to include(delivered: true, public_id: be_present)
      expect(CommandTower::HomeNotice.find_by!(identity: identity_for(user))).to have_attributes(
        user_id: user.id, kind: "delivery", key: "dfm.class_canceled", campaign_key: nil, period_key: "",
        communication_id:, metadata: { "class_id" => 1 }
      )
    end

    context "when already delivered" do
      before { deliver(user:, notice:, communication_id:) }

      it "is idempotent on user and identity", :aggregate_failures do
        expect(result.data).to include(
          delivered: false, public_id: CommandTower::HomeNotice.find_by!(identity: identity_for(user)).public_id
        )
        expect(CommandTower::HomeNotice.where(identity: identity_for(user)).count).to eq(1)
      end
    end
  end

  describe "an unavailable linked message" do
    let(:communication_id) { 0 }

    it "fails with linked_message_unavailable and writes nothing", :aggregate_failures do
      expect(result).to be_failure
      expect(result.errors.first.code).to eq("linked_message_unavailable")
      expect(CommandTower::HomeNotice.count).to eq(0)
    end
  end

  describe "a linked message without a communication id" do
    let(:communication_id) { nil }

    it "fails with linked_message_unavailable" do
      expect(result.errors.first.code).to eq("linked_message_unavailable")
    end
  end

  describe "an inbox item of another user" do
    let(:communication_id) { create_inbox_for(user: create(:user)).communication_id }

    it "fails with linked_message_unavailable" do
      expect(result.errors.first.code).to eq("linked_message_unavailable")
    end
  end

  describe "the open-delivery cap" do
    before do
      open_row(user:)
      allow(CommandTower.config.home_notices).to receive(:max_open_deliveries).and_return(1)
    end

    it "ignores the delivery", :aggregate_failures do
      expect(result).to be_success
      expect(result.data).to include(delivered: false, public_id: nil)
      expect(CommandTower::HomeNotice.where(identity: identity_for(user))).to be_none
    end

    context "when the open row is acknowledged" do
      before do
        CommandTower::HomeNotice.update_all(acknowledged_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      end

      it "does not count acknowledged rows" do
        expect(result.data).to include(delivered: true)
      end
    end
  end

  describe "a notice that is not a Delivery" do
    let(:notice) { Class.new(CommandTower::HomeNotices::Campaign) }

    it "fails" do
      expect(result).to be_failure
    end
  end
end
