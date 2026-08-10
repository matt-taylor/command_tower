# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::Evaluator, :messaging_preferences do
  let(:recipient_id) { 42 }
  let(:platform_enabled_channels) { %w[email sms push] }
  let(:preference_state) { nil }

  let(:evaluate) do
    described_class.call(
      notification_type_key:,
      recipient_id:,
      preference_state:,
      platform_enabled_channels:,
    )
  end

  describe "unknown type" do
    let(:notification_type_key) { "unknown.type" }

    it "fails closed with UnknownTypeError" do
      expect { evaluate }.to raise_error(
        CommandTower::Messaging::Preferences::UnknownTypeError,
      )
    end
  end

  context "with a registered optional user-configurable type" do
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
      )
    end

    context "when preference_state is absent" do
      subject(:result) { evaluate }

      it "applies declaration defaults when preference_state is absent" do
        expect(result.notification_type_key).to eq("booking.success")
        expect(result.recipient_id).to eq(42)
        expect(result.permitted_channels).to contain_exactly("email", "sms")
        expect(result.inbox_permitted).to be(true)
        expect(result.mandatory).to be(false)
        expect(result.mandatory_enforced).to be(false)
        expect(result.suppressed_destinations).to be_empty
      end
    end

    context "when recipient preference disables a channel" do
      let(:preference_state) do
        build_preference_state(
          channels: { "email" => true, "sms" => false },
          inbox: true,
        )
      end

      subject(:result) { evaluate }

      it "suppresses channels disabled by recipient preference" do
        expect(result.permitted_channels).to eq(["email"])
        expect(result.suppressed_destinations).to contain_exactly(
          have_attributes(
            destination: "sms",
            reason_class: CommandTower::Messaging::Preferences::ReasonClasses::SUPPRESSED_BY_PREFERENCE,
          ),
        )
      end
    end

    context "when all channels and inbox are disabled" do
      let(:preference_state) do
        build_preference_state(
          channels: { "email" => false, "sms" => false },
          inbox: false,
        )
      end

      subject(:result) { evaluate }

      it "allows an empty permitted set for optional types" do
        expect(result.permitted_channels).to be_empty
        expect(result.inbox_permitted).to be(false)
        expect(result.suppressed_destinations.map(&:destination)).to contain_exactly("email", "sms", :inbox)
      end
    end

    context "when a channel is not platform-enabled" do
      let(:platform_enabled_channels) { %w[email] }

      subject(:result) { evaluate }

      it "skips channels that are not platform-enabled" do
        expect(result.permitted_channels).to eq(["email"])
        expect(result.suppressed_destinations).to contain_exactly(
          have_attributes(
            destination: "sms",
            reason_class: CommandTower::Messaging::Preferences::ReasonClasses::SKIPPED_BY_POLICY,
          ),
        )
      end
    end

    context "when preference includes channels outside the allowed set" do
      let(:preference_state) do
        build_preference_state(
          channels: { "email" => true, "push" => true },
          inbox: true,
        )
      end

      subject(:result) { evaluate }

      it "never permits channels outside the type allowed set" do
        expect(result.permitted_channels).to include("email")
        expect(result.permitted_channels).not_to include("push")
        expect(result.suppressed_destinations).to include(
          have_attributes(
            destination: "push",
            reason_class: CommandTower::Messaging::Preferences::ReasonClasses::SKIPPED_BY_POLICY,
          ),
        )
      end
    end
  end

  context "with a mandatory type" do
    let(:notification_type_key) { "security.alert" }

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
          allowed_channels: %w[email sms],
          default_channels: %w[email],
          inbox_available: true,
          user_configurable: true,
          mandatory: true,
          default_preference_state: {
            "channels" => { "email" => true, "sms" => true },
            "inbox" => true,
          },
        ),
      )
    end

    context "when recipient preference disables required destinations" do
      let(:preference_state) do
        build_preference_state(
          channels: { "email" => false, "sms" => false },
          inbox: false,
        )
      end

      subject(:result) { evaluate }

      it "enforces required posture and sets mandatory_enforced" do
        expect(result.mandatory).to be(true)
        expect(result.mandatory_enforced).to be(true)
        expect(result.permitted_channels).to include("email")
        expect(result.inbox_permitted).to be(true)
        expect(result.suppressed_destinations.map(&:destination)).to contain_exactly("sms")
      end
    end
  end

  context "with a non-user-configurable type" do
    let(:notification_type_key) { "system.notice" }

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
          allowed_channels: %w[email],
          default_channels: %w[email],
          inbox_available: true,
          user_configurable: false,
          mandatory: false,
          default_preference_state: {
            "channels" => { "email" => true },
            "inbox" => true,
          },
        ),
      )
    end

    context "when recipient preference overrides defaults" do
      let(:preference_state) do
        build_preference_state(
          channels: { "email" => false },
          inbox: false,
        )
      end

      subject(:result) { evaluate }

      it "ignores recipient preference overrides" do
        expect(result.permitted_channels).to eq(["email"])
        expect(result.inbox_permitted).to be(true)
        expect(result.suppressed_destinations).to be_empty
      end
    end
  end

  context "when inbox is not available on the type" do
    let(:notification_type_key) { "channel.only" }

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
          allowed_channels: %w[email],
          default_channels: %w[email],
          inbox_available: false,
          user_configurable: true,
          mandatory: false,
          default_preference_state: {
            "channels" => { "email" => true },
            "inbox" => true,
          },
        ),
      )
    end

    context "when prefs request inbox" do
      let(:preference_state) { build_preference_state(channels: { "email" => true }, inbox: true) }

      subject(:result) { evaluate }

      it "does not permit inbox even when prefs request it" do
        expect(result.inbox_permitted).to be(false)
        expect(result.suppressed_destinations.map(&:destination)).not_to include(:inbox)
      end
    end
  end

  describe "malformed preference state" do
    let(:notification_type_key) { "booking.success" }

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(key: notification_type_key),
      )
    end

    it "raises InvalidPreferenceStateError" do
      expect {
        described_class.call(
          notification_type_key:,
          recipient_id:,
          preference_state: "nope",
          platform_enabled_channels:,
        )
      }.to raise_error(CommandTower::Messaging::Preferences::InvalidPreferenceStateError)
    end
  end
end

RSpec.describe CommandTower::Messaging::Preferences, :messaging_preferences do
  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(key: "facade.type"),
    )
  end

  subject(:result) do
    described_class.evaluate(
      notification_type_key: "facade.type",
      recipient_id: 1,
      preference_state: nil,
      platform_enabled_channels: %w[email sms],
    )
  end

  it "exposes evaluate on the module façade" do
    expect(result).to be_a(CommandTower::Messaging::Preferences::EvaluationResult)
    expect(result.permitted_channels).to include("email")
  end
end
