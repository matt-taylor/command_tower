# frozen_string_literal: true

# Regression guard: types without a MessageDefinition keep today's Accept and
# Produce behavior while definition-backed columns are added.
RSpec.describe CommandTower::Messaging::Accept::Persister, :messaging_accept do
  let(:user) { create(:user) }
  let(:notification_type_key) { "legacy.undefined" }
  let(:produce_attrs) do
    { notification_type_key:, title: "Hello", body: "Body text", platform_enabled_channels: [] }
  end
  let(:fingerprint_kwargs) do
    {
      title: "Hello",
      body: "World",
      metadata: { "b" => 2, "a" => 1 },
      preference_state: nil,
      platform_enabled_channels: %w[sms email],
      message_overrides: nil
    }
  end

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email sms],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: { "channels" => { "email" => true, "sms" => true }, "inbox" => true }
      )
    )
  end

  describe "fingerprint basis" do
    let(:normalizer) { CommandTower::Messaging::Accept::RequestNormalizer }

    it "is built from title, body, metadata, preference_state, channels and overrides" do
      expect(JSON.parse(normalizer.new(**fingerprint_kwargs).canonical_json).keys).to eq(
        %w[title body metadata preference_state platform_enabled_channels message_overrides]
      )
    end

    it "changes when the title changes" do
      expect(normalizer.fingerprint(**fingerprint_kwargs, title: "Other"))
        .not_to eq(normalizer.fingerprint(**fingerprint_kwargs))
    end

    it "changes when the body changes" do
      expect(normalizer.fingerprint(**fingerprint_kwargs, body: "Other"))
        .not_to eq(normalizer.fingerprint(**fingerprint_kwargs))
    end

    it "ignores metadata key order" do
      expect(normalizer.fingerprint(**fingerprint_kwargs, metadata: { "a" => 1, "b" => 2 }))
        .to eq(normalizer.fingerprint(**fingerprint_kwargs))
    end
  end

  describe "persisted row" do
    let(:communication) do
      accepted = CommandTower::Messaging.accept(
        **default_accept_attrs(user:, notification_type_key:, platform_enabled_channels: %w[email])
      )
      CommandTower::Messaging::Communication.find(accepted.communication_id)
    end

    it "keeps the supplied title" do
      expect(communication.title).to be_present
    end

    it "writes NULL definition columns" do
      expect(communication.slice(:slots, :render_zone, :metadata_version).values).to all(be_nil)
    end

    it "is not definition-backed" do
      expect(communication).not_to be_message_definition_backed
    end

    it "stores SQL NULL, not a JSON empty object, in slots" do
      expect(
        ActiveRecord::Base.connection.select_value(
          "SELECT slots FROM messaging_communications WHERE id = #{communication.id.to_i}"
        )
      ).to be_nil
    end
  end

  describe "Produce family" do
    let(:produced) do
      CommandTower::Services::Messaging::Communications::Produce.call(
        user:, host_event_identity: "legacy/#{user.id}/1", **produce_attrs
      )
    end

    it "Produce accepts explicit title and body" do
      expect(CommandTower::Messaging::Communication.where(id: produced.data[:communication_id]).pluck(:body))
        .to eq(["Body text"])
    end

    it "Produce rejects a missing title" do
      expect(
        CommandTower::Services::Messaging::Communications::Produce.call(
          user:, host_event_identity: "legacy/#{user.id}/2", **produce_attrs, title: nil
        )
      ).not_to be_success
    end

    it "ProduceMany accepts explicit title and body" do
      expect(
        CommandTower::Services::Messaging::Communications::ProduceMany.call(
          user_ids: [user.id], campaign_identity: "legacy-campaign", execution_mode: :sync, **produce_attrs
        ).data
      ).to include(accepted: 1, failed: 0)
    end

    it "ProduceRecipientWorkflow accepts explicit title and body" do
      expect(
        CommandTower::Workflows::Messaging::Communications::ProduceRecipientWorkflow.call_from_job(
          user_id: user.id, campaign_identity: "legacy-job", **produce_attrs
        )
      ).to be_success
    end
  end
end
