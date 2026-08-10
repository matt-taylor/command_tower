# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Planner::Planner, :messaging_planner do
  let(:user) { create(:user) }
  let(:recipient_id) { user.id }
  let(:platform_enabled_channels) { %w[email sms push] }
  let(:message_overrides) { nil }
  let(:notification_type_key) { "booking.success" }

  let(:plan) do
    lambda do |**overrides|
      described_class.call(
        notification_type_key:,
        recipient_id:,
        preference_state: nil,
        platform_enabled_channels:,
        message_overrides:,
        **overrides,
      )
    end
  end

  let(:stub_sms_configured!) do
    lambda do |value = true|
      allow(
        CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
      ).to receive(:sms_configured?).and_return(value)
    end
  end

  describe "unknown type" do
    subject(:invoke) { plan.call }

    it "fails closed with UnknownTypeError" do
      expect { invoke }.to raise_error(CommandTower::Messaging::Planner::UnknownTypeError)
    end
  end

  context "with an optional registered type" do
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

    subject(:result) { plan.call }

    it "seeds selected channels from defaults intersect permitted prefs" do
      expect(result).to be_a(CommandTower::Messaging::Planner::DestinationPlan)
      expect(result.notification_type_key).to eq("booking.success")
      expect(result.recipient_id).to eq(recipient_id)
      expect(result.selected_channels).to eq(["email"])
      expect(result.inbox_selected).to be(true)
      expect(result.mandatory).to be(false)
      expect(result.preference_evaluation).to be_a(
        CommandTower::Messaging::Preferences::EvaluationResult,
      )
      expect(result.preference_evaluation.stored_override_present).to be(false)
      expect(result.excluded_destinations.map(&:destination)).to include("sms")
    end

    context "when email is unverified" do
      before { user.update!(email_validated: false) }

      subject(:result) { plan.call }

      it "excludes unreadiness with readiness reason codes" do
        expect(result.selected_channels).to be_empty
        expect(
          result.excluded_destinations.find { |item| item.destination == "email" }.reason_class,
        ).to eq(
          CommandTower::Messaging::RecipientReadiness::ReasonCodes::IDENTITY_UNVERIFIED,
        )
      end
    end

    context "when stored prefs suppress everything" do
      before do
        upsert_notification_preference!(
          recipient_id:,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => false },
            inbox: false,
          ),
        )
      end

      subject(:result) { plan.call }

      it "allows an empty optional plan" do
        expect(result.selected_channels).to be_empty
        expect(result.inbox_selected).to be(false)
        expect(result.excluded_destinations).not_to be_empty
        expect(result.preference_evaluation.stored_override_present).to be(true)
      end
    end

    context "when host-supplied preference_state is provided" do
      subject(:invoke) do
        plan.call(preference_state: build_preference_state(channels: { "email" => false }, inbox: true))
      end

      it "rejects host-supplied preference_state" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Planner::InvalidEvaluationError,
          /preference_state must not be supplied/,
        )
      end
    end

    context "when adding a permitted ready channel via message overrides" do
      before do
        stub_sms_configured!.call
        user.update!(phone_number: "+14155552671", phone_number_validated: true)
      end

      subject(:result) { plan.call(message_overrides: { "channels_add" => %w[sms] }) }

      it "adds the channel" do
        expect(result.selected_channels).to contain_exactly("email", "sms")
      end
    end

    context "when override adds a not-ready channel" do
      before do
        stub_sms_configured!.call
        user.update!(phone_number: "+14155552671", phone_number_validated: false)
      end

      subject(:invoke) { plan.call(message_overrides: { "channels_add" => %w[sms] }) }

      it "rejects override that adds a not-ready channel" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Planner::IllegalOverrideError,
          /not recipient-ready/,
        )
      end
    end

    context "when removing a channel via message overrides" do
      subject(:result) { plan.call(message_overrides: { "channels_remove" => %w[email] }) }

      it "removes a channel via message overrides" do
        expect(result.selected_channels).to be_empty
        expect(result.excluded_destinations.map(&:destination)).to include("email")
      end
    end

    context "when override adds a channel outside the allowed set" do
      subject(:invoke) { plan.call(message_overrides: { "channels_add" => %w[push] }) }

      it "rejects override that adds a channel outside the allowed set" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Planner::IllegalOverrideError)
      end
    end

    context "when override adds a preference-suppressed channel" do
      before do
        upsert_notification_preference!(
          recipient_id:,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => true, "sms" => false },
            inbox: true,
          ),
        )
      end

      subject(:invoke) { plan.call(message_overrides: { "channels_add" => %w[sms] }) }

      it "rejects override that adds a preference-suppressed channel" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Planner::IllegalOverrideError)
      end
    end

    context "when override attempts mandatory elevation" do
      subject(:invoke) { plan.call(message_overrides: { "force_mandatory" => true }) }

      it "rejects mandatory elevation via overrides" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Planner::IllegalOverrideError)
      end
    end

    context "when called twice with the same inputs" do
      let(:first) { plan.call }
      let(:second) { plan.call }

      it "is deterministic for the same inputs" do
        expect(first.selected_channels).to eq(second.selected_channels)
        expect(first.inbox_selected).to eq(second.inbox_selected)
        expect(first.excluded_destinations).to eq(second.excluded_destinations)
      end
    end
  end

  context "with SMS in defaults when recipient is SMS-ready" do
    let(:notification_type_key) { "booking.sms_default" }

    before do
      stub_sms_configured!.call
      user.update!(phone_number: "+14155552671", phone_number_validated: true)
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
          allowed_channels: %w[email sms],
          default_channels: %w[email sms],
          inbox_available: false,
          user_configurable: true,
          mandatory: false,
          default_preference_state: {
            "channels" => { "email" => true, "sms" => true },
            "inbox" => false,
          },
        ),
      )
    end

    subject(:result) { plan.call }

    it "selects ready SMS and email" do
      expect(result.selected_channels).to contain_exactly("email", "sms")
    end

    context "when phone is cleared" do
      before { user.update!(phone_number: nil, phone_number_validated: false) }

      subject(:result) { plan.call }

      it "excludes SMS with readiness reason" do
        expect(result.selected_channels).to eq(["email"])
        expect(
          result.excluded_destinations.find { |item| item.destination == "sms" }.reason_class,
        ).to eq(
          CommandTower::Messaging::RecipientReadiness::ReasonCodes::IDENTITY_MISSING,
        )
      end
    end
  end

  context "with a mandatory type that cannot be satisfied" do
    let(:notification_type_key) { "security.alert" }

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: notification_type_key,
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

    context "when no destinations can be selected" do
      subject(:invoke) { plan.call(platform_enabled_channels: []) }

      it "fails closed when no destinations can be selected" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Planner::ImpossibleMandatoryPlanError)
      end
    end

    context "when unreadiness excludes the only destination" do
      before { user.update!(email_validated: false) }

      subject(:invoke) { plan.call }

      it "fails closed when unreadiness excludes the only destination" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Planner::ImpossibleMandatoryPlanError)
      end
    end
  end
end

RSpec.describe CommandTower::Messaging::Planner, :messaging_planner do
  context "when using the module façade" do
    let(:user) { create(:user) }

    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(key: "facade.plan"),
      )
    end

    subject(:result) do
      described_class.plan(
        notification_type_key: "facade.plan",
        recipient_id: user.id,
        platform_enabled_channels: %w[email sms],
      )
    end

    it "exposes plan on the module façade" do
      expect(result).to be_a(CommandTower::Messaging::Planner::DestinationPlan)
      expect(result.selected_channels).to include("email")
    end
  end
end
