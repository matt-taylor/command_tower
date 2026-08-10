# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Store, :messaging_preferences do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }

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
      build_notification_type_declaration(
        key: "password.changed",
        allowed_channels: %w[email],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: false,
        mandatory: true,
        default_preference_state: {
          "channels" => { "email" => true },
          "inbox" => true,
        },
        label: "Password Changed",
        category_key: "account",
        category_label: "Account",
        category_order: 30,
        type_order: 10,
      ),
    )
  end

  describe ".find" do
    it "returns nil when no row exists" do
      expect(
        described_class.find(recipient_id: user.id, notification_type_key:),
      ).to be_nil
    end

    it "returns a PreferenceState for a stored sparse override" do
      described_class.upsert!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "email" => false }, inbox: true),
      )

      found = described_class.find(recipient_id: user.id, notification_type_key:)
      expect(found).to be_a(CommandTower::Messaging::Preferences::PreferenceState)
      expect(found.channels).to eq("email" => false)
      expect(found.inbox).to be(true)
    end

    context "with corrupt stored JSON" do
      before do
        CommandTower::Messaging::NotificationPreference.create!(
          user_id: user.id,
          notification_type_key:,
          state: { "channels" => "bad" },
        )
      end

      it "raises InvalidPreferenceStateError" do
        expect {
          described_class.find(recipient_id: user.id, notification_type_key:)
        }.to raise_error(CommandTower::Messaging::Preferences::InvalidPreferenceStateError)
      end
    end
  end

  describe ".upsert!" do
    it "creates and updates a unique preference row" do
      described_class.upsert!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "email" => false }),
      )
      described_class.upsert!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "sms" => false }, inbox: false),
      )

      expect(CommandTower::Messaging::NotificationPreference.count).to eq(1)
      found = described_class.find(recipient_id: user.id, notification_type_key:)
      expect(found.channels).to eq("sms" => false)
      expect(found.inbox).to be(false)
    end

    it "rejects unknown notification types" do
      expect {
        described_class.upsert!(
          recipient_id: user.id,
          notification_type_key: "missing.type",
          preference_state: build_preference_state(channels: { "email" => true }),
        )
      }.to raise_error(CommandTower::Messaging::Preferences::UnknownTypeError)
    end

    it "rejects non-user-configurable types" do
      expect {
        described_class.upsert!(
          recipient_id: user.id,
          notification_type_key: "password.changed",
          preference_state: build_preference_state(channels: { "email" => false }),
        )
      }.to raise_error(
        CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
        /not user-configurable/,
      )
    end

    it "rejects channels outside the allowed set" do
      expect {
        described_class.upsert!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(channels: { "push" => true }),
        )
      }.to raise_error(
        CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
        /outside allowed set/,
      )
    end

    it "enforces uniqueness at the database" do
      described_class.upsert!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "email" => false }),
      )

      expect {
        CommandTower::Messaging::NotificationPreference.create!(
          user_id: user.id,
          notification_type_key:,
          state: { "channels" => { "email" => true } },
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".delete!" do
    it "removes an existing preference row" do
      described_class.upsert!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: build_preference_state(channels: { "email" => false }),
      )

      described_class.delete!(recipient_id: user.id, notification_type_key:)

      expect(
        described_class.find(recipient_id: user.id, notification_type_key:),
      ).to be_nil
      expect(CommandTower::Messaging::NotificationPreference.count).to eq(0)
    end

    it "is a no-op when no row exists" do
      expect {
        described_class.delete!(recipient_id: user.id, notification_type_key:)
      }.not_to raise_error
    end
  end
end
