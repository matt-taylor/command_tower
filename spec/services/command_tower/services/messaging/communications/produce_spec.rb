# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Communications::Produce, :messaging_accept do
  describe ".call" do
    let(:user) { create(:user, email: "produce-user@example.com", username: "produceuser") }
    let(:notification_type_key) { "booking.success" }
    let(:platform_enabled_channels) { [] }
    let(:host_event_identity) { "booking.success/#{user.id}/fixed-identity" }
    let(:title) { "Booking confirmed" }
    let(:body) { "Your booking was confirmed." }
    let(:metadata) { nil }
    let(:call_kwargs) do
      {
        user:,
        notification_type_key:,
        host_event_identity:,
        title:,
        body:,
        metadata:,
        platform_enabled_channels:,
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
          default_preference_state: {
            "channels" => { "email" => true, "sms" => true },
            "inbox" => true,
          },
        ),
      )
    end

    context "with a persisted user and registered type" do
      subject(:result) { described_class.call(**call_kwargs) }

      it "returns a successful ServiceResult" do
        expect(result).to be_success
      end

      it "exposes Accept result fields on data" do
        expect(result.data).to include(
          recipient_id: user.id,
          notification_type_key:,
          host_event_identity:,
          communication_status: "accepted",
          idempotent_replay: false,
          selected_channels: [],
          inbox_selected: true,
        )
        expect(result.data[:communication_id]).to be_present
        expect(result.data[:destination_plan_id]).to be_present
        expect(result.data[:inbox_item_id]).to be_present
      end

      it "persists an inbox-only aggregate when no channels are enabled" do
        result

        communication = CommandTower::Messaging::Communication.find(result.data[:communication_id])
        expect(communication.user_id).to eq(user.id)
        expect(communication.notification_type_key).to eq(notification_type_key)
        expect(communication.status).to eq("accepted")
        expect(communication.destination_plan).to be_present
        expect(communication.inbox_item).to be_present
        expect(communication.channel_deliveries).to be_empty
        expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
      end

      it "enqueues HandoffJob after commit" do
        result

        expect(CommandTower::Messaging::HandoffJob).to have_been_enqueued.with(result.data[:communication_id])
      end
    end

    context "when passing host platform_enabled_channels" do
      subject(:result) { described_class.call(**call_kwargs) }

      let(:platform_enabled_channels) { %w[email] }

      before do
        allow(CommandTower::Messaging).to receive(:accept).and_call_original
      end

      it "forwards the supplied channels to Accept" do
        result

        expect(CommandTower::Messaging).to have_received(:accept).with(
          hash_including(
            recipient_id: user.id,
            notification_type_key:,
            platform_enabled_channels: %w[email],
            preference_state: nil,
            message_overrides: nil,
          )
        )
      end
    end

    context "when Accept is replayed with the same identity and content" do
      subject(:second_result) { described_class.call(**call_kwargs) }

      let!(:first_result) { described_class.call(**call_kwargs) }

      before do
        clear_enqueued_jobs
      end

      it "returns idempotent_replay without duplicating rows or re-enqueueing handoff" do
        expect(second_result).to be_success
        expect(second_result.data[:idempotent_replay]).to be(true)
        expect(second_result.data[:communication_id]).to eq(first_result.data[:communication_id])
        expect(CommandTower::Messaging::Communication.count).to eq(1)
        expect(CommandTower::Messaging::DestinationPlan.count).to eq(1)
        expect(CommandTower::Messaging::InboxItem.count).to eq(1)
        expect(CommandTower::Messaging::HandoffJob).not_to have_been_enqueued
      end
    end

    context "when the user cannot be resolved" do
      subject(:result) { described_class.call(**call_kwargs) }

      let(:user) { build(:user, email: "unsaved-produce@example.com", username: "unsavedproduce") }

      it "propagates RecipientUnresolvedError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Messaging::RecipientUnresolvedError)
        )
      end
    end

    context "when user is nil" do
      subject(:result) do
        described_class.call(
          user: nil,
          notification_type_key:,
          host_event_identity: "booking.success/missing",
          title:,
          body:,
          platform_enabled_channels:,
        )
      end

      it "returns ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end

    context "when platform_enabled_channels is omitted" do
      subject(:result) do
        described_class.call(
          user:,
          notification_type_key:,
          host_event_identity:,
          title:,
          body:,
        )
      end

      it "returns ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end

    shared_examples "maps Accept exception to application error" do |accept_error_class, application_error_class|
      subject(:result) { described_class.call(**call_kwargs) }

      before do
        allow(CommandTower::Messaging).to receive(:accept).and_raise(accept_error_class, "mapped")
      end

      it "returns #{application_error_class}" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(application_error_class))
        expect(result.errors.first.retryable?).to be(false)
      end
    end

    context "when Accept raises ValidationError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::ValidationError,
                       CommandTower::Errors::ValidationError
    end

    context "when Accept raises UnknownTypeError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::UnknownTypeError,
                       CommandTower::Errors::Messaging::AcceptRejectedError
    end

    context "when Accept raises InvalidPreferenceError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::InvalidPreferenceError,
                       CommandTower::Errors::Messaging::AcceptRejectedError
    end

    context "when Accept raises IllegalOverrideError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::IllegalOverrideError,
                       CommandTower::Errors::Messaging::AcceptRejectedError
    end

    context "when Accept raises ImpossibleMandatoryPlanError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::ImpossibleMandatoryPlanError,
                       CommandTower::Errors::Messaging::AcceptRejectedError
    end

    context "when Accept raises IdempotencyConflictError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::IdempotencyConflictError,
                       CommandTower::Errors::Messaging::IdempotencyConflictError
    end

    context "when Accept raises PersistenceError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::PersistenceError,
                       CommandTower::Errors::InternalError
    end

    context "when Accept raises InvariantError" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::InvariantError,
                       CommandTower::Errors::InternalError
    end

    context "when Accept raises a generic Accept::Error" do
      include_examples "maps Accept exception to application error",
                       CommandTower::Messaging::Accept::Error,
                       CommandTower::Errors::InternalError
    end

    context "when metadata and title/body are supplied" do
      subject(:result) { described_class.call(**call_kwargs) }

      let(:metadata) { { "deep_link" => "/bookings/1" } }
      let(:title) { "Custom title" }
      let(:body) { "Custom body" }

      before do
        allow(CommandTower::Messaging).to receive(:accept).and_call_original
      end

      it "passes metadata, title, and body through to Accept" do
        result

        expect(CommandTower::Messaging).to have_received(:accept).with(
          hash_including(
            title: "Custom title",
            body: "Custom body",
            metadata: { "deep_link" => "/bookings/1" },
          )
        )
      end
    end
  end
end
