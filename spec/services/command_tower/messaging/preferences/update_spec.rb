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

  context "when a partial write omits channel entries" do
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

    it "merges onto the stored member document and keeps unmentioned channel entries" do
      expect(stored.to_raw_hash).to eq(
        "channels" => { "email" => false, "sms" => false },
        "inbox" => false,
      )
    end
  end

  context "when an old client sends only channels and inbox" do
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
          urgency: { default: "normal", allowed: %w[normal time_sensitive] },
        ),
      )
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: {
          "channels" => { "email" => false },
          "urgency" => "time_sensitive",
        },
      )
    end

    subject(:result) do
      update!.call(
        preference_state: {
          "channels" => { "email" => false },
          "inbox" => false,
        },
      )
    end

    let(:stored) do
      result
      CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
    end

    it "keeps stored urgency when the body omits it" do
      expect(stored.urgency).to eq("time_sensitive")
      expect(stored.channels).to eq("email" => false)
      expect(stored.inbox).to be(false)
      expect(result.urgency[:effective]).to eq("time_sensitive")
    end
  end

  context "when an invalid write is rejected" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: { "channels" => { "email" => false }, "inbox" => false },
      )
    end

    let(:before_hash) do
      CommandTower::Messaging::Preferences.find_stored(
        recipient_id: user.id,
        notification_type_key:,
      ).to_raw_hash
    end

    it "does not change the stored row" do
      expect {
        update!.call(preference_state: { "channels" => { "email" => "nope" } })
      }.to raise_error(CommandTower::Messaging::Preferences::InvalidPreferenceStateError)

      expect(
        CommandTower::Messaging::Preferences.find_stored(
          recipient_id: user.id,
          notification_type_key:,
        ).to_raw_hash,
      ).to eq(before_hash)
    end
  end

  context "when an unknown top-level key is submitted" do
    before do
      CommandTower::Messaging::Preferences.upsert_stored!(
        recipient_id: user.id,
        notification_type_key:,
        preference_state: { "channels" => { "email" => false } },
      )
    end

    it "rejects the write and leaves the row unchanged" do
      before_hash =
        CommandTower::Messaging::Preferences.find_stored(
          recipient_id: user.id,
          notification_type_key:,
        ).to_raw_hash

      expect {
        update!.call(preference_state: { "mandatory" => true, "channels" => { "email" => false } })
      }.to raise_error(
        CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
        /unsupported preference keys/,
      )

      expect(
        CommandTower::Messaging::Preferences.find_stored(
          recipient_id: user.id,
          notification_type_key:,
        ).to_raw_hash,
      ).to eq(before_hash)
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

  context "with a forced_on destination lock" do
    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
          allowed_channels: %w[email push],
          default_channels: %w[email],
          default_preference_state: {
            "channels" => { "email" => true, "push" => false },
            "inbox" => true,
          },
          destination_locks: { "push" => "forced_on" },
        ),
      )
    end

    it "persists the locked channel when the patch omits it" do
      update!.call(preference_state: { "channels" => { "email" => false } })

      stored = CommandTower::Messaging::Preferences.find_stored(
        recipient_id: user.id,
        notification_type_key:,
      )
      expect(stored.channels["push"]).to be(true)
    end
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

  context "when urgency is fixed" do
    subject(:invoke) { update!.call(preference_state: { "urgency" => "normal" }) }

    it "rejects the write" do
      expect { invoke }.to raise_error(
        CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
        /urgency is not selectable/,
      )
    end
  end

  context "with a restricted urgency" do
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
          urgency: { default: "normal", allowed: %w[normal time_sensitive] },
        ),
      )
    end

    context "when the member chooses a permitted level" do
      subject(:result) { update!.call(preference_state: { "urgency" => "time_sensitive" }) }

      let(:stored) do
        result
        CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
      end

      it "stores the level and leaves channels unchanged" do
        expect(stored.urgency).to eq("time_sensitive")
        expect(stored.channels).to eq({})
        expect(result.channels["email"]).to be(true)
        expect(result.urgency[:effective]).to eq("time_sensitive")
      end
    end

    context "when the member submits the default" do
      subject(:result) { update!.call(preference_state: { "urgency" => "normal" }) }

      let(:stored) do
        result
        CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
      end

      it "does not store an override" do
        expect(stored).to be_nil
        expect(result.urgency[:effective]).to eq("normal")
      end
    end

    context "when the level is outside the permitted list" do
      subject(:invoke) { update!.call(preference_state: { "urgency" => "critical" }) }

      it "rejects the write" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
          /urgency is not permitted/,
        )
      end
    end

    context "when a later write omits urgency" do
      before do
        update!.call(preference_state: { "urgency" => "time_sensitive", "channels" => { "email" => false } })
      end

      subject(:result) { update!.call(preference_state: { "channels" => { "email" => false } }) }

      let(:stored) do
        result
        CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
      end

      it "keeps the stored urgency override and the channel entry" do
        expect(stored.urgency).to eq("time_sensitive")
        expect(stored.channels).to eq("email" => false)
        expect(result.urgency[:effective]).to eq("time_sensitive")
      end
    end

    context "when a channel is reset to the declaration default" do
      let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }

      around do |example|
        previous = CommandTower.config.messaging.sounds
        CommandTower.config.messaging.sounds = host_sounds
        example.run
      ensure
        CommandTower.config.messaging.sounds = previous
      end

      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: notification_type_key,
            allowed_channels: %w[email sms],
            default_channels: %w[email],
            inbox_available: true,
            user_configurable: true,
            settings_visible: true,
            default_preference_state: {
              "channels" => { "email" => true, "sms" => true },
              "inbox" => true,
            },
            urgency: { default: "normal", allowed: %w[normal time_sensitive] },
            sound: { default: "default", allowed: "all" },
          ),
        )
        CommandTower::Messaging::Preferences.upsert_stored!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: {
            "channels" => { "email" => false, "sms" => false },
            "inbox" => false,
            "urgency" => "time_sensitive",
            "sound" => "chime",
          },
        )
      end

      subject(:result) { update!.call(preference_state: { "channels" => { "email" => true } }) }

      let(:stored) do
        result
        CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
      end

      it "drops only that channel override and keeps the other stored fields" do
        expect(stored.channels).to eq("sms" => false)
        expect(stored.channels).not_to have_key("email")
        expect(stored.inbox).to be(false)
        expect(stored.urgency).to eq("time_sensitive")
        expect(stored.sound).to eq("chime")
        expect(result.channels).to eq("email" => true, "sms" => false)
      end
    end

    context "when preferences is empty" do
      before { update!.call(preference_state: { "urgency" => "time_sensitive" }) }

      subject(:result) { update!.call(preference_state: {}) }

      let(:stored) do
        result
        CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
      end

      it "resets the row" do
        expect(stored).to be_nil
        expect(result.stored_override_present).to be(false)
      end
    end
  end

  context "with a full sound catalog" do
    let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }

    around do |example|
      previous = CommandTower.config.messaging.sounds
      CommandTower.config.messaging.sounds = host_sounds
      example.run
    ensure
      CommandTower.config.messaging.sounds = previous
    end

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
          allowed_channels: %w[email],
          default_channels: %w[email],
          inbox_available: true,
          user_configurable: true,
          settings_visible: true,
          default_preference_state: { "channels" => { "email" => true }, "inbox" => true },
          sound: { default: "default", allowed: "all" },
        ),
      )
    end

    context "when the member chooses a registered sound" do
      subject(:result) { update!.call(preference_state: { "sound" => "chime" }) }

      let(:stored) do
        result
        CommandTower::Messaging::Preferences.find_stored(recipient_id: user.id, notification_type_key:)
      end

      it "stores the sound without an asset name in the block" do
        expect(stored.sound).to eq("chime")
        expect(result.sound[:effective]).to eq("chime")
        expect(result.sound[:allowed]).to eq(
          [
            { id: "default", label: "System Default" },
            { id: "chime", label: "Chime" },
          ],
        )
      end
    end

    context "when the sound is not registered" do
      subject(:invoke) { update!.call(preference_state: { "sound" => "bell" }) }

      it "rejects the write" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Preferences::InvalidPreferenceWriteError,
          /sound is not permitted/,
        )
      end
    end
  end
end
