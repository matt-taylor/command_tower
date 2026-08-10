# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Accept::Coordinator, :messaging_accept do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms] }

  let(:accept) do
    lambda do |**overrides|
      described_class.call(
        **default_accept_attrs(user:, notification_type_key:, platform_enabled_channels:, **overrides),
      )
    end
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
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => true,
        },
      ),
    )
  end

  describe "public façade" do
    subject(:result) { CommandTower::Messaging.accept(**default_accept_attrs(user:)) }

    it "returns an immutable Accept::Result without ActiveRecord objects" do
      expect(result).to be_a(CommandTower::Messaging::Accept::Result)
      expect(result).not_to be_a(ActiveRecord::Base)
      expect(result.channel_deliveries).to all(be_a(CommandTower::Messaging::Accept::ChannelDeliveryResult))
      expect(result.idempotent_replay).to be(false)
      expect(result.status).to eq("accepted")
    end
  end

  describe "happy paths" do
    context "when SMS platform configuration is enabled" do
      before do
        allow(
          CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
        ).to receive(:sms_configured?).and_return(true)
        user.update!(phone_number: "+14155552671", phone_number_validated: true)
      end

      subject(:result) { accept.call(message_overrides: { "channels_add" => %w[sms] }) }

      let(:communication) { CommandTower::Messaging::Communication.find(result.communication_id) }

      it "persists a multi-destination plan with deterministic ordering" do
        expect(result.selected_channels).to eq(%w[email sms])
        expect(result.channel_deliveries.map(&:channel_key)).to eq(%w[email sms])
        expect(result.inbox_selected).to be(true)
        expect(result.inbox_item_id).to be_present
        expect(result.destination_plan_id).to be_present
        expect(communication.destination_plan.decision["platform_enabled_channels"]).to eq(%w[email sms])
        expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
        expect(CommandTower::Messaging::ChannelDelivery.pluck(:status).uniq).to eq(["planned"])
        expect(CommandTower::Messaging::InboxItem.pluck(:status).uniq).to eq(["created"])
      end
    end

    context "when channels are suppressed" do
      before do
        upsert_notification_preference!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => false },
            inbox: true,
          ),
        )
      end

      subject(:result) { accept.call }

      it "persists an inbox-only plan when channels are suppressed" do
        expect(result.selected_channels).to be_empty
        expect(result.channel_deliveries).to be_empty
        expect(result.inbox_selected).to be(true)
        expect(result.inbox_item_id).to be_present
      end
    end

    context "when inbox is unavailable" do
      before do
        MessagingNotificationTypesHelper.reset_notification_type_registry!
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "channel.only",
            allowed_channels: %w[email],
            default_channels: %w[email],
            inbox_available: false,
            user_configurable: true,
            mandatory: false,
            default_preference_state: {
              "channels" => { "email" => true },
              "inbox" => false,
            },
          ),
        )
      end

      subject(:result) do
        accept.call(notification_type_key: "channel.only", platform_enabled_channels: %w[email])
      end

      it "persists a channel-only plan when inbox is unavailable" do
        expect(result.inbox_selected).to be(false)
        expect(result.inbox_item_id).to be_nil
        expect(result.selected_channels).to eq(["email"])
      end
    end

    context "when all destinations are suppressed" do
      before do
        upsert_notification_preference!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => false },
            inbox: false,
          ),
        )
      end

      subject(:result) { accept.call }

      it "persists an optional empty plan" do
        expect(result.selected_channels).to be_empty
        expect(result.inbox_selected).to be(false)
        expect(result.inbox_item_id).to be_nil
        expect(result.channel_deliveries).to be_empty
        expect(CommandTower::Messaging::Communication.count).to eq(1)
        expect(CommandTower::Messaging::DestinationPlan.count).to eq(1)
      end
    end

    context "when host-supplied preference_state is provided" do
      subject(:invoke) do
        accept.call(
          preference_state: build_preference_state(
            channels: { "email" => false },
            inbox: true,
          ),
        )
      end

      it "rejects host-supplied preference_state" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Accept::ValidationError,
          /preference_state must not be supplied/,
        )
      end
    end
  end

  describe "idempotency" do
    context "for an equivalent duplicate request" do
      let!(:first) { accept.call }
      let!(:second) { accept.call }

      it "returns the original result for an equivalent duplicate request" do
        expect(second.idempotent_replay).to be(true)
        expect(second.communication_id).to eq(first.communication_id)
        expect(second.destination_plan_id).to eq(first.destination_plan_id)
        expect(second.selected_channels).to eq(first.selected_channels)
        expect(second.channel_deliveries.map(&:id)).to eq(first.channel_deliveries.map(&:id))
        expect(CommandTower::Messaging::Communication.count).to eq(1)
      end
    end

    context "on successful replay" do
      before { accept.call }

      it "does not call Planner on successful replay" do
        expect(CommandTower::Messaging::Planner).not_to receive(:plan)
        accept.call
      end
    end

    context "when the title changes under the same namespace" do
      before { accept.call }

      subject(:invoke) { accept.call(title: "Different title") }

      it "conflicts when the title changes under the same namespace" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Accept::IdempotencyConflictError)
        expect(CommandTower::Messaging::Communication.count).to eq(1)
      end
    end

    context "when preference_state is injected on replay" do
      before { accept.call }

      subject(:invoke) do
        accept.call(
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => true },
            inbox: true,
          ),
        )
      end

      it "rejects preference_state injection rather than treating it as an override" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Accept::ValidationError,
          /preference_state must not be supplied/,
        )
      end
    end

    context "when hashes are normalized-equivalent" do
      let!(:first) { accept.call(metadata: { "b" => 2, "a" => 1 }) }
      let!(:second) { accept.call(metadata: { "a" => 1, "b" => 2 }) }

      it "replays when hashes are normalized-equivalent" do
        expect(second.idempotent_replay).to be(true)
        expect(second.communication_id).to eq(first.communication_id)
      end
    end
  end

  describe "planner failures" do
    context "for an unknown type" do
      subject(:invoke) { accept.call(notification_type_key: "unknown.type") }

      it "persists nothing for an unknown type" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Accept::UnknownTypeError)
        expect(CommandTower::Messaging::Communication.count).to eq(0)
      end
    end

    context "for a mandatory impossible plan" do
      before do
        MessagingNotificationTypesHelper.reset_notification_type_registry!
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "security.alert",
            allowed_channels: %w[email],
            default_channels: %w[email],
            inbox_available: false,
            user_configurable: true,
            mandatory: true,
            default_preference_state: {
              "channels" => { "email" => true },
              "inbox" => false,
            },
          ),
        )
      end

      subject(:invoke) do
        accept.call(
          notification_type_key: "security.alert",
          platform_enabled_channels: [],
        )
      end

      it "persists nothing for a mandatory impossible plan" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Accept::ImpossibleMandatoryPlanError)
        expect(CommandTower::Messaging::Communication.count).to eq(0)
      end
    end
  end

  describe "atomicity" do
    context "when destination plan persistence fails" do
      before do
        allow(CommandTower::Messaging::DestinationPlan).to receive(:create!).and_raise(
          ActiveRecord::RecordInvalid.new(CommandTower::Messaging::DestinationPlan.new),
        )
      end

      subject(:invoke) { accept.call }

      it "rolls back when destination plan persistence fails" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Accept::PersistenceError)
        expect(CommandTower::Messaging::Communication.count).to eq(0)
        expect(CommandTower::Messaging::InboxItem.count).to eq(0)
        expect(CommandTower::Messaging::ChannelDelivery.count).to eq(0)
      end
    end
  end

  describe "database uniqueness" do
    context "when inserting duplicate channel_key for the same communication" do
      let(:accept_result) { accept.call }

      subject(:invoke) do
        CommandTower::Messaging::ChannelDelivery.insert!({
          communication_id: accept_result.communication_id,
          channel_key: "email",
          status: "planned",
          created_at: Time.current,
          updated_at: Time.current,
        })
      end

      it "rejects duplicate channel_key for the same communication" do
        expect { invoke }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context "when ChannelDelivery persistence hits a non-idempotency uniqueness conflict" do
      let(:plan) do
        instance_double(
          CommandTower::Messaging::Planner::DestinationPlan,
          inbox_selected: false,
          selected_channels: %w[email],
          mandatory: false,
          excluded_destinations: [],
        )
      end

      before do
        allow(CommandTower::Messaging::Planner).to receive(:plan).and_return(plan)
        allow(CommandTower::Messaging::ChannelDelivery).to receive(:create!).and_raise(
          ActiveRecord::RecordNotUnique.new("Duplicate entry"),
        )
      end

      subject(:invoke) { accept.call }

      it "maps non-idempotency uniqueness failures to PersistenceError" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Accept::PersistenceError)
      end
    end
  end

  describe "handoff initialization" do
    subject(:result) { accept.call }

    let(:communication) { CommandTower::Messaging::Communication.find(result.communication_id) }

    it "writes pending handoff status and does not create DeliveryAttempts" do
      expect(communication.execution_handoff_status).to eq("pending")
      expect(CommandTower::Messaging::ChannelDelivery.pluck(:status).uniq).to eq(["planned"])
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
    end
  end

  describe "concurrency" do
    let(:barrier) { Queue.new }
    let(:errors) { Queue.new }
    let(:results) { Queue.new }

    before do
      threads = Array.new(2) do
        Thread.new do
          barrier.pop
          begin
            results << accept.call
          rescue StandardError => e
            errors << e
          end
        end
      end

      2.times { barrier << :go }
      threads.each(&:join)
    end

    it "creates exactly one communication for simultaneous equivalent accepts" do
      expect(errors).to be_empty
      expect(results.size).to eq(2)
      expect(Array.new(2) { results.pop.communication_id }.uniq.size).to eq(1)
      expect(CommandTower::Messaging::Communication.count).to eq(1)
    end
  end
end
