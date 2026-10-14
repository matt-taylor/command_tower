# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::PushPresentation, :messaging_notification_types do
  subject(:presentation) { described_class.call(communication:) }

  let(:user) { create(:user) }
  let(:type_key) { "booking.reminder" }
  let(:conversation) { {} }
  let(:communication) do
    create(:messaging_communication, user:, notification_type_key: type_key, **conversation)
  end
  let(:urgency) { { default: "normal", allowed: %w[normal time_sensitive] } }
  let(:sound) { { default: "default", allowed: %w[default chime] } }
  let(:user_configurable) { true }
  let(:badge_eligible) { false }
  let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }
  let(:stored_state) { {} }

  around do |example|
    previous = CommandTower.config.messaging.sounds
    example.run
  ensure
    CommandTower.config.messaging.sounds = previous
  end

  before do
    CommandTower.config.messaging.sounds = host_sounds
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: type_key,
        urgency:,
        sound:,
        user_configurable:,
        badge_eligible:,
      ),
    )
    unless stored_state.nil?
      create(
        :messaging_notification_preference,
        user:,
        notification_type_key: type_key,
        state: { "channels" => {}, "inbox" => true }.merge(stored_state),
      )
    end
  end

  context "when the member has no stored choice" do
    let(:stored_state) { nil }

    it "uses the declared defaults" do
      expect(presentation).to have_attributes(urgency: "normal", sound: nil, thread_id: nil, badge: nil)
    end

    it "is frozen" do
      expect(presentation).to be_frozen
    end
  end

  context "when the member stored a permitted urgency and sound" do
    let(:stored_state) { { "urgency" => "time_sensitive", "sound" => "chime" } }

    it "uses the stored urgency and the catalog asset for the stored sound" do
      expect(presentation).to have_attributes(urgency: "time_sensitive", sound: "chime.wav")
    end
  end

  context "when the member stored System Default explicitly" do
    let(:sound) { { default: "chime", allowed: %w[default chime] } }
    let(:stored_state) { { "sound" => "default" } }

    it "returns no asset" do
      expect(presentation.sound).to be_nil
    end
  end

  context "when the declared default sound is a host sound" do
    let(:sound) { { default: "chime", allowed: %w[chime] } }
    let(:stored_state) { nil }

    it "returns the host asset" do
      expect(presentation.sound).to eq("chime.wav")
    end
  end

  context "when the stored values are no longer permitted" do
    let(:urgency) { { default: "normal", allowed: %w[normal] } }
    let(:sound) { { default: "default", allowed: %w[default] } }
    let(:stored_state) { { "urgency" => "time_sensitive", "sound" => "chime" } }

    it "falls back to the declared defaults" do
      expect(presentation).to have_attributes(urgency: "normal", sound: nil)
    end
  end

  context "when the stored sound is not registered in the catalog" do
    let(:stored_state) { { "sound" => "gone" } }

    it "falls back to the declared default" do
      expect(presentation.sound).to be_nil
    end
  end

  context "when the type is fixed" do
    let(:urgency) { { default: "normal", allowed: %w[normal] } }
    let(:sound) { { default: "default", allowed: %w[default] } }
    let(:stored_state) { nil }

    it "uses the fixed values" do
      expect(presentation).to have_attributes(urgency: "normal", sound: nil)
    end
  end

  context "when the type is not user-configurable" do
    let(:user_configurable) { false }
    let(:stored_state) { { "urgency" => "time_sensitive", "sound" => "chime" } }

    it "ignores the stored override and does not read it" do
      expect(CommandTower::Messaging::Preferences::Store).not_to receive(:find)

      expect(presentation).to have_attributes(urgency: "normal", sound: nil)
    end
  end

  describe "preference reads" do
    let(:stored_state) { { "urgency" => "time_sensitive" } }

    it "reads the stored preference exactly once per render" do
      expect(CommandTower::Messaging::Preferences::Store).to receive(:find).once.and_call_original

      presentation
    end
  end

  describe "thread identity" do
    context "when the communication has a conversation key" do
      let(:conversation) { { conversation_key: "league.7.period.3", conversation_title: "Friends · Week 3" } }

      it "returns the key as the thread id" do
        expect(presentation.thread_id).to eq("league.7.period.3")
      end
    end

    context "when the communication is standalone" do
      it "returns no thread id" do
        expect(presentation.thread_id).to be_nil
      end
    end
  end

  context "when the type is not registered" do
    let(:type_key) { "booking.reminder" }
    let(:communication) do
      create(
        :messaging_communication,
        user:,
        notification_type_key: "removed.type",
        conversation_key: "league.7.period.3",
        conversation_title: "Friends · Week 3",
      )
    end

    it "returns defaults, keeps the thread, and records a fallback" do
      expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_presentation_fallback).with(
        communication:,
        reason_code: "type_unregistered",
        channel_delivery: nil,
      )

      expect(presentation).to have_attributes(
        urgency: "normal",
        sound: nil,
        thread_id: "league.7.period.3",
        badge: nil,
      )
    end
  end

  context "when the stored preference cannot be read" do
    let(:stored_state) { nil }

    before do
      allow(CommandTower::Messaging::Preferences::Store).to receive(:find)
        .and_raise(CommandTower::Messaging::Preferences::StoreError, "boom")
    end

    it "returns defaults and records a fallback" do
      expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_presentation_fallback).with(
        communication:,
        reason_code: "preference_unreadable",
        channel_delivery: nil,
      )

      expect(presentation).to have_attributes(urgency: "normal", sound: nil, badge: nil)
    end
  end

  context "when the stored preference is invalid" do
    let(:stored_state) { nil }

    before do
      allow(CommandTower::Messaging::Preferences::Store).to receive(:find)
        .and_raise(CommandTower::Messaging::Preferences::InvalidPreferenceStateError, "bad")
    end

    it "returns defaults and records a fallback" do
      expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_presentation_fallback).with(
        communication:,
        reason_code: "preference_unreadable",
        channel_delivery: nil,
      )

      expect(presentation.urgency).to eq("normal")
    end
  end

  context "when an unexpected error occurs" do
    let(:stored_state) { nil }

    before do
      allow(CommandTower::Messaging::Preferences::Store).to receive(:find).and_raise(NoMethodError, "bug")
    end

    it "does not rescue it or record a fallback" do
      expect(CommandTower::Messaging::Execution::OperationLogger).not_to receive(:push_presentation_fallback)

      expect { presentation }.to raise_error(NoMethodError, "bug")
    end
  end

  describe "badge count" do
    let(:other_eligible_item) do
      create(
        :messaging_inbox_item,
        communication: create(:messaging_communication, user:, notification_type_key: "badge.on"),
      )
    end

    context "when the type is badge eligible and this message is unread" do
      let(:badge_eligible) { true }

      before { create(:messaging_inbox_item, communication:) }

      it "returns the reader's absolute count, including this item" do
        expect(presentation.badge).to eq(1)
        expect(presentation.badge).to eq(
          CommandTower::Messaging::Inbox.unread_count(recipient_id: user.id).badge_count,
        )
      end

      it "reads the unread count once" do
        expect(CommandTower::Messaging::Inbox).to receive(:unread_count).once.and_call_original

        expect(presentation.badge).to eq(1)
      end
    end

    context "when the eligible type has no unread rows" do
      let(:badge_eligible) { true }

      it "returns zero" do
        expect(presentation.badge).to eq(0)
      end
    end

    context "when the type is not badge eligible" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: type_key,
            urgency:,
            sound:,
            user_configurable:,
            badge_eligible: false,
          ),
          build_notification_type_declaration(
            key: "badge.on",
            badge_eligible: true,
            category_key: "other",
            category_label: "Other",
            category_order: 11,
            type_order: 11,
          ),
        )
        other_eligible_item
      end

      it "omits the badge and does not query the unread count" do
        expect(CommandTower::Messaging::Inbox).not_to receive(:unread_count)

        expect(presentation.badge).to be_nil
      end

      context "when the type is push_delivery_test" do
        let(:type_key) { "push_delivery_test" }

        it "omits the badge and does not query the unread count" do
          expect(CommandTower::Messaging::Inbox).not_to receive(:unread_count)

          expect(presentation.badge).to be_nil
        end
      end
    end

    context "when eligible rows are viewed, archived, or deleted" do
      let(:badge_eligible) { true }

      before do
        create(:messaging_inbox_item, communication:)
        create(
          :messaging_inbox_item,
          :viewed,
          communication: create(:messaging_communication, user:, notification_type_key: type_key),
        )
        create(
          :messaging_inbox_item,
          :archived,
          communication: create(:messaging_communication, user:, notification_type_key: type_key),
        )
        create(
          :messaging_inbox_item,
          :deleted,
          communication: create(:messaging_communication, user:, notification_type_key: type_key),
        )
      end

      it "counts only the live unread item" do
        expect(presentation.badge).to eq(1)
      end
    end

    context "when this communication has no inbox item" do
      let(:badge_eligible) { true }

      context "with an older eligible unread item" do
        before do
          create(
            :messaging_inbox_item,
            communication: create(:messaging_communication, user:, notification_type_key: type_key),
          )
        end

        it "returns the current eligible count" do
          expect(presentation.badge).to eq(1)
        end
      end

      context "with no eligible unread items" do
        it "returns zero" do
          expect(presentation.badge).to eq(0)
        end
      end
    end

    context "when channel preferences are off" do
      let(:badge_eligible) { true }
      let(:stored_state) { { "channels" => { "push" => false, "email" => false }, "inbox" => false } }

      before { create(:messaging_inbox_item, communication:) }

      it "still counts the unread item" do
        expect(presentation.badge).to eq(1)
      end
    end

    context "when another member has an eligible unread item" do
      let(:badge_eligible) { true }

      before do
        create(:messaging_inbox_item, communication:)
        create(
          :messaging_inbox_item,
          communication: create(
            :messaging_communication,
            user: create(:user),
            notification_type_key: type_key,
          ),
        )
      end

      it "counts only this recipient" do
        expect(presentation.badge).to eq(1)
      end
    end

    context "when the preference cannot be read for a badge-eligible type" do
      let(:badge_eligible) { true }
      let(:stored_state) { nil }

      before do
        create(:messaging_inbox_item, communication:)
        allow(CommandTower::Messaging::Preferences::Store).to receive(:find)
          .and_raise(CommandTower::Messaging::Preferences::StoreError, "boom")
      end

      it "keeps the badge count and records a fallback" do
        expect(CommandTower::Messaging::Execution::OperationLogger).to receive(:push_presentation_fallback).with(
          communication:,
          reason_code: "preference_unreadable",
          channel_delivery: nil,
        )

        expect(presentation).to have_attributes(urgency: "normal", sound: nil, badge: 1)
      end
    end

    context "when the unread count fails" do
      let(:badge_eligible) { true }
      let(:stored_state) { nil }

      before do
        allow(CommandTower::Messaging::Inbox).to receive(:unread_count)
          .and_raise(ActiveRecord::StatementInvalid, "db down")
      end

      it "does not rescue the database error or record a fallback" do
        expect(CommandTower::Messaging::Execution::OperationLogger).not_to receive(:push_presentation_fallback)

        expect { presentation }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end
end
