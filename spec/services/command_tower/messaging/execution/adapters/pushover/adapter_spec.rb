# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Pushover::Adapter, :messaging_accept do
  let(:user) { create(:user) }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      host_event_identity: "pushover-adapter-#{SecureRandom.hex(4)}",
      accept_request_fingerprint: "fp",
      status: "accepted",
      execution_handoff_status: "enqueued",
      title: "Hello",
      body: "World",
    )
  end
  let(:delivery) do
    create(
      :messaging_channel_delivery,
      communication:,
      channel_key: "pushover",
      status: "queued",
    )
  end
  let(:endpoint) do
    view = CommandTower::Messaging::Endpoints.create(
      owner_user_id: user.id,
      channel_key: "pushover",
      credentials: {
        user_key: "u" + ("a" * 30),
        application_token: "t" + ("b" * 30),
      },
    )
    record = CommandTower::Messaging::Endpoint.find(view.id)
    record.update!(verification_state: "verified", verified_at: Time.current)
    record
  end

  let(:build_request) do
    lambda do |endpoint_id: endpoint.id|
      rendered = CommandTower::Messaging::Rendering::RenderedPushoverPayload.build(
        recipient_address: endpoint_id.to_s,
        title: "Hello",
        message: "World",
      )
      CommandTower::Messaging::Execution::AdapterRequest.build(
        channel_delivery_id: delivery.id,
        communication_id: communication.id,
        channel_key: "pushover",
        attempt_id: 3,
        rendered:,
      )
    end
  end

  let(:configured) do
    instance_double(
      CommandTower::Messaging::Execution::Adapters::Pushover::Configuration,
      pushover_configured?: true,
    )
  end

  around do |example|
    previous = CommandTower.config.messaging.pushover.adapter
    CommandTower.config.messaging.pushover.adapter = "fake"
    CommandTower::Messaging::Pushover::Transport.reset_adapter!
    CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
    example.run
  ensure
    CommandTower.config.messaging.pushover.adapter = previous
    CommandTower::Messaging::Pushover::Transport.reset_adapter!
    CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
  end

  context "with a successful send" do
    subject(:result) { described_class.new(configuration: configured).call(request: build_request.call) }

    it "sends through Transport and maps success with safe provider metadata" do
      expect(result.success?).to eq(true)
      expect(result.normalized_provider_status).to eq("accepted")
      expect(result.provider_message_id).to be_present
      expect(CommandTower::Messaging::Pushover::Adapters::FakeAdapter.messages.size).to eq(1)
    end
  end

  context "when the transport times out" do
    before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :timeout }

    subject(:result) { described_class.new(configuration: configured).call(request: build_request.call) }

    it "maps timeout to retryable without mark_invalid" do
      expect(CommandTower::Messaging::Endpoints).not_to receive(:mark_invalid)
      expect(result.retryable_failure?).to eq(true)
      expect(result.error_code).to eq("pushover_transient")
    end
  end

  context "when credentials are invalid" do
    before { CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_user }

    subject(:result) { described_class.new(configuration: configured).call(request: build_request.call) }

    it "maps invalid credentials to terminal and marks endpoint invalid" do
      expect(CommandTower::Messaging::Endpoints).to receive(:mark_invalid).with(
        owner_user_id: user.id,
        endpoint_id: endpoint.id,
      ).and_call_original
      expect(result.terminal_failure?).to eq(true)
      expect(result.error_code).to eq("pushover_rejected")
      expect(endpoint.reload.lifecycle_state).to eq("invalid")
    end
  end

  context "during delivery" do
    subject(:invoke) { described_class.new(configuration: configured).call(request: build_request.call) }

    it "does not call verify_pushover! during delivery" do
      expect(CommandTower::Messaging::Endpoints).not_to receive(:verify_pushover!)
      invoke
    end
  end

  context "when not configured" do
    let(:unconfigured_config) do
      instance_double(
        CommandTower::Messaging::Execution::Adapters::Pushover::Configuration,
        pushover_configured?: false,
      )
    end

    subject(:result) { described_class.new(configuration: unconfigured_config).call(request: build_request.call) }

    it "returns adapter_unconfigured when not configured" do
      expect(result.terminal_failure?).to eq(true)
      expect(result.error_code).to eq("adapter_unconfigured")
    end
  end
end
