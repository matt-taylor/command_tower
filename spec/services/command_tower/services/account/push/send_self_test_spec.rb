# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Push::SendSelfTest, :messaging_notification_types do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }
    let(:address) { "ExponentPushToken[selftest01]" }
    let(:push_delivery_test) do
      build_notification_type_declaration(
        key: "push_delivery_test",
        allowed_channels: %w[push],
        default_channels: %w[push],
        inbox_available: false,
        user_configurable: false,
        mandatory: false,
        default_preference_state: {
          "channels" => { "push" => true },
          "inbox" => false,
        },
        label: "Push delivery test",
        category_key: "system",
        category_label: "System",
        category_order: 1,
        type_order: 1,
        settings_visible: false,
        deep_link_required: true,
      )
    end

    before do
      @previous_self_test = CommandTower.config.messaging.expo.self_test_deep_link
      CommandTower.config.messaging.expo.self_test_deep_link = "/account/push-notifications"
      register_and_seal_notification_types(push_delivery_test)
      previous_channels = CommandTower.config.messaging.platform_enabled_channels
      CommandTower.config.messaging.platform_enabled_channels = -> { %w[inbox push] }
      @previous_channels = previous_channels
      previous = CommandTower.config.messaging.expo.adapter
      CommandTower.config.messaging.expo.adapter = "fake"
      CommandTower.config.messaging.allow_fake_adapter = true
      @previous_adapter = previous
    end

    after do
      CommandTower.config.messaging.expo.adapter = @previous_adapter
      CommandTower.config.messaging.platform_enabled_channels = @previous_channels
      CommandTower.config.messaging.expo.self_test_deep_link = @previous_self_test
    end

    context "when the user has no active push endpoint" do
      it "fails with push_test_no_endpoint" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushTestNoEndpointError)
      end
    end

    context "when the user has an active endpoint" do
      before do
        CommandTower::Services::Account::Push::Create.call(user:, address:)
      end

      it { expect(result).to be_success }

      let(:communication) { CommandTower::Messaging::Communication.find(result.data[:communication_id]) }

      it "produces a push_delivery_test communication selecting push" do
        expect(result.data[:communication_id]).to be_present
        expect(result.data[:selected_channels]).to include("push")
        expect(result.data[:communication_status]).to be_present
      end

      it "stores the self-test deep link and creates no inbox item" do
        expect(communication.metadata["deep_link"]).to eq("/account/push-notifications")
        expect(communication.inbox_item).to be_nil
      end
    end

    context "when the self-test deep link is unresolved" do
      before do
        CommandTower::Services::Account::Push::Create.call(user:, address:)
        CommandTower.config.messaging.expo.self_test_deep_link = -> { " " }
      end

      it "fails before Produce" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushTestDestinationError)
        expect(CommandTower::Messaging::Communication.count).to eq(0)
      end
    end

    context "when rate limited" do
      before do
        CommandTower::Services::Account::Push::Create.call(user:, address:)
        allow(CommandTower::Services::Account::Push::CheckSelfTestRateLimit)
          .to receive(:call).and_return(
            CommandTower::Services::ServiceResult.failure(
              errors: [CommandTower::Errors::Account::PushTestRateLimitError.new(retry_after_seconds: 60)],
            ),
          )
      end

      it "propagates the rate limit error" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushTestRateLimitError)
      end
    end
  end
end
