# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Messaging::Communications::ProduceRecipientWorkflow, :messaging_accept do
  let(:user) { create(:user) }
  let(:notification_type_key) { "promo.job" }
  let(:campaign_identity) { "campaign/job-1" }

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: [],
        default_channels: [],
        inbox_available: true,
        user_configurable: false,
        mandatory: false,
        default_preference_state: { "channels" => {}, "inbox" => true },
      ),
    )
  end

  context "with a persisted user" do
    subject(:result) do
      described_class.call_from_job(
        user_id: user.id,
        notification_type_key:,
        campaign_identity:,
        title: "Hi",
        body: "Body",
        platform_enabled_channels: [],
      )
    end

    it "produces for a reloaded user via call_from_job" do
      expect(result).to be_success
      expect(
        CommandTower::Messaging::Communication.find_by(
          user_id: user.id,
          host_event_identity: "#{campaign_identity}/#{user.id}",
        )
      ).to be_present
    end
  end

  context "when the user is missing" do
    subject(:result) do
      described_class.call_from_job(
        user_id: 9_999_999_999,
        notification_type_key:,
        campaign_identity:,
        title: "Hi",
        body: "Body",
        platform_enabled_channels: [],
      )
    end

    it "returns not found without propagating when user is missing" do
      expect(result).to be_failure
      expect(result.meta[:propagate_to_job]).to eq(false)
    end
  end
end
