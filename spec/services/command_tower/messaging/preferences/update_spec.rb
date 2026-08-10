# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Update, :messaging_preferences do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms] }

  let(:update!) do
    lambda do |preference_state:|
      described_class.call(
        recipient_id: user.id,
        notification_type_key:,
        preference_state:,
        platform_enabled_channels:,
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
        settings_visible: true,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => true,
        },
      ),
      build_notification_type_declaration(
        key: "password.changed",
        label: "Password Changed",
        category_key: "account",
        category_label: "Account",
        category_order: 30,
        type_order: 10,
        allowed_channels: %w[email],
        default_channels: %w[email],
        user_configurable: false,
        mandatory: true,
        settings_visible: true,
        default_preference_state: {
          "channels" => { "email" => true },
          "inbox" => true,
        },
      ),
      build_notification_type_declaration(
        key: "hello_world",
        label: "Hello World",
        category_key: "development",
        category_label: "Development",
        category_order: 1000,
        type_order: 10,
        allowed_channels: [],
        default_channels: [],
        user_configurable: true,
        settings_visible: false,
        default_preference_state: {
          "channels" => {},
          "inbox" => true,
        },
      ),
      build_notification_type_declaration(
        key: "security.alert",
        label: "Security Alert",
        category_key: "account",
        category_label: "Account",
        category_order: 30,
        type_order: 20,
        allowed_channels: %w[email],
        default_channels: %w[email],
        user_configurable: true,
        mandatory: true,
        settings_visible: true,
        default_preference_state: {
          "channels" => { "email" => true },
          "inbox" => true,
        },
      ),
      build_notification_type_declaration(
        key: "inbox.only",
        label: "Inbox Only",
        category_key: "account",
        category_label: "Account",
        category_order: 30,
        type_order: 30,
        allowed_channels: [],
        default_channels: [],
        inbox_available: false,
        user_configurable: true,
        settings_visible: true,
        default_preference_state: {
          "channels" => {},
          "inbox" => nil,
        },
      ),
    )
  end

  context "when updating preferences" do
    subject(:result) do
      update!.call(preference_state: { "channels" => { "email" => false }, "inbox" => true })
    end

    let(:stored) do
      result
      CommandTower::Messaging::Preferences.find_stored(
        recipient_id: user.id,
        notification_type_key:,
      )
    end

    it "updates preferences and returns a catalog notification result" do
      expect(result).to be_a(CommandTower::Messaging::Preferences::CatalogNotificationResult)
      expect(result.key).to eq(notification_type_key)
      expect(result.channels).to eq("email" => false, "sms" => true)
      expect(result.inbox_enabled).to be(true)
      expect(result.stored_override_present).to be(true)
      expect(stored.to_raw_hash).to eq("channels" => { "email" => false })
    end
  end

  context "when replacing a prior stored override" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: { "channels" => { "email" => false, "sms" => false }, "inbox" => false },
      )
      update!.call(preference_state: { "channels" => { "email" => false } })
    end

    let(:stored) do
      CommandTower::Messaging::Preferences.find_stored(
        recipient_id: user.id,
        notification_type_key:,
      )
    end

    it "replaces the prior stored override rather than merging" do
      expect(stored.to_raw_hash).to eq("channels" => { "email" => false })
      expect(stored.channels).not_to have_key("sms")
    end
  end

  context "when values match declaration defaults" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: { "channels" => { "email" => false } },
      )
    end

    subject(:result) do
      update!.call(
        preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => true,
        },
      )
    end

    it "sparsifies values that match declaration defaults and deletes empty overrides" do
      expect(result.stored_override_present).to be(false)
      expect(
        CommandTower::Messaging::Preferences.find_stored(
          recipient_id: user.id,
          notification_type_key:,
        ),
      ).to be_nil
    end
  end

  context "when preference_state is empty" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: { "channels" => { "email" => false } },
      )
    end

    subject(:result) { update!.call(preference_state: {}) }

    it "resets to defaults when preference_state is empty" do
      expect(result.stored_override_present).to be(false)
      expect(result.channels).to eq("email" => true, "sms" => true)
      expect(result.inbox_enabled).to be(true)
      expect(
        CommandTower::Messaging::Preferences.find_stored(
          recipient_id: user.id,
          notification_type_key:,
        ),
      ).to be_nil
    end
  end

  it "rejects unknown notification types" do
    expect {
      described_class.call(
        recipient_id: user.id,
        notification_type_key: "missing.type",
        preference_state: { "channels" => { "email" => false } },
      )
    }.to raise_error(CommandTower::Messaging::Preferences::UnknownTypeError)
  end

  it "rejects settings-hidden notification types" do
    expect {
      described_class.call(
        recipient_id: user.id,
        notification_type_key: "hello_world",
        preference_state: { "inbox" => false },
      )
    }.to raise_error(CommandTower::Messaging::Preferences::NotSettingsVisibleError)
  end

  it "rejects non-configurable notification types" do
    expect {
      described_class.call(
        recipient_id: user.id,
        notification_type_key: "password.changed",
        preference_state: { "channels" => { "email" => false } },
      )
    }.to raise_error(CommandTower::Messaging::Preferences::InvalidPreferenceWriteError)
  end

  it "rejects unsupported inbox preferences" do
    expect {
      described_class.call(
        recipient_id: user.id,
        notification_type_key: "inbox.only",
        preference_state: { "inbox" => true },
      )
    }.to raise_error(
      CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
      /inbox preference is not available/,
    )
  end

  it "rejects unknown channels" do
    expect {
      update!.call(preference_state: { "channels" => { "push" => false } })
    }.to raise_error(
      CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
      /outside allowed set/,
    )
  end

  it "rejects non-boolean channel values" do
    expect {
      update!.call(preference_state: { "channels" => { "email" => "nope" } })
    }.to raise_error(CommandTower::Messaging::Preferences::InvalidPreferenceStateError)
  end

  context "with mandatory destination disables" do
    subject(:result) do
      described_class.call(
        recipient_id: user.id,
        notification_type_key: "security.alert",
        preference_state: { "channels" => { "email" => false }, "inbox" => false },
        platform_enabled_channels: %w[email],
      )
    end

    let(:evaluation) do
      result
      CommandTower::Messaging::Preferences.resolve(
        notification_type_key: "security.alert",
        recipient_id: user.id,
        platform_enabled_channels: %w[email],
      )
    end

    it "accepts mandatory destination disables and returns evaluator-enforced effective state" do
      expect(result.stored_override_present).to be(true)
      expect(result.mandatory).to be(true)
      expect(result.channels["email"]).to be(false)
      expect(evaluation.mandatory_enforced).to be(true)
      expect(evaluation.permitted_channels).to include("email")
      expect(evaluation.inbox_permitted).to be(true)
    end
  end

  context "with repeated identical updates" do
    let(:first) { update!.call(preference_state: { "channels" => { "email" => false } }) }

    subject(:second) do
      first
      update!.call(preference_state: { "channels" => { "email" => false } })
    end

    it "is idempotent for repeated identical updates" do
      expect(second.channels).to eq(first.channels)
      expect(second.stored_override_present).to eq(first.stored_override_present)
    end
  end

  context "when Store raises" do
    before do
      allow(CommandTower::Messaging::Preferences::Store).to receive(:upsert!).and_raise(
        CommandTower::Messaging::Preferences::StoreError,
        "db down",
      )
    end

    it "fails closed when Store raises" do
      expect {
        update!.call(preference_state: { "channels" => { "email" => false } })
      }.to raise_error(CommandTower::Messaging::Preferences::StoreError)
    end
  end

  context "through the Preferences.update façade" do
    subject(:result) do
      CommandTower::Messaging::Preferences.update(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: { "channels" => { "email" => false } },
        platform_enabled_channels:,
      )
    end

    it "delegates through the Preferences.update façade" do
      expect(result.key).to eq(notification_type_key)
      expect(result.stored_override_present).to be(true)
    end
  end
end
