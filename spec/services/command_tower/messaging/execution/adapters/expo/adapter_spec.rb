# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Expo::Adapter, :messaging_accept do
  let(:user) { create(:user) }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      host_event_identity: "expo-adapter-#{SecureRandom.hex(4)}",
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
      channel_key: "push",
      status: "queued",
    )
  end

  let(:create_verified_push!) do
    lambda do |address:|
      view = CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "push",
        address:,
      )
      record = CommandTower::Messaging::Endpoint.find(view.id)
      record.update!(verification_state: "verified", verified_at: Time.current)
      record
    end
  end

  let(:build_request) do
    lambda do |endpoint_ids:|
      rendered = CommandTower::Messaging::Rendering::RenderedPushPayload.build(
        recipient_address: endpoint_ids.first.to_s,
        title: "Hello",
        body: "World",
        deep_link: "pickem://home",
      )
      CommandTower::Messaging::Execution::AdapterRequest.build(
        channel_delivery_id: delivery.id,
        communication_id: communication.id,
        channel_key: "push",
        attempt_id: 3,
        rendered:,
        eligible_endpoint_ids: endpoint_ids,
      )
    end
  end

  let(:configured) do
    instance_double(
      CommandTower::Messaging::Execution::Adapters::Expo::Configuration,
      expo_configured?: true,
      adapter_name: adapter_name,
      api_base_url: "https://exp.host/--/api/v2/push",
      timeout_seconds: 5,
      access_token: "",
    )
  end
  let(:adapter_name) { "fake" }

  around do |example|
    previous = CommandTower.config.messaging.expo.adapter
    CommandTower.config.messaging.expo.adapter = "fake"
    example.run
  ensure
    CommandTower.config.messaging.expo.adapter = previous
  end

  context "with the fake adapter and one eligible endpoint" do
    let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[aaaa1111]") }

    subject(:result) do
      described_class.new(configuration: configured).call(
        request: build_request.call(endpoint_ids: [endpoint.id]),
      )
    end

    it "returns success without HTTP" do
      expect(result.success?).to eq(true)
      expect(result.normalized_provider_status).to eq("accepted")
    end
  end

  context "when eligible_endpoint_ids is empty" do
    let(:rendered) do
      CommandTower::Messaging::Rendering::RenderedPushPayload.build(
        recipient_address: "0",
        title: "Hello",
        body: "World",
      )
    end
    let(:request) do
      CommandTower::Messaging::Execution::AdapterRequest.build(
        channel_delivery_id: delivery.id,
        communication_id: communication.id,
        channel_key: "push",
        attempt_id: 3,
        rendered:,
        eligible_endpoint_ids: [],
      )
    end

    subject(:result) { described_class.new(configuration: configured).call(request:) }

    it "returns recipient_missing" do
      expect(result.terminal_failure?).to eq(true)
      expect(result.error_code).to eq("recipient_missing")
    end
  end

  context "with http adapter" do
    let(:adapter_name) { "http" }
    let(:http_client) do
      instance_double(CommandTower::Messaging::Execution::Adapters::Expo::HttpClient)
    end

    context "when one endpoint yields ticket and receipt ok" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[bbbb2222]") }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-1", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).with(["ticket-1"]).and_return(
          ok: true,
          status_code: 200,
          receipts: { "ticket-1" => { status: "ok", message: nil, error: nil } },
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "maps success with provider ticket id" do
        expect(result.success?).to eq(true)
        expect(result.provider_message_id).to eq("ticket-1")
        expect(http_client).to have_received(:send_messages) do |messages|
          expect(messages.size).to eq(1)
          expect(messages.first["to"]).to eq("ExponentPushToken[bbbb2222]")
          expect(messages.first["data"]).to eq("deepLink" => "pickem://home")
        end
      end
    end

    context "when two endpoints are eligible" do
      let!(:first) { create_verified_push!.call(address: "ExponentPushToken[cccc3333]") }
      let!(:second) { create_verified_push!.call(address: "ExponentPushToken[dddd4444]") }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [
            { status: "ok", id: "t-a", message: nil, error: nil },
            { status: "ok", id: "t-b", message: nil, error: nil },
          ],
        )
        allow(http_client).to receive(:get_receipts).with(%w[t-a t-b]).and_return(
          ok: true,
          status_code: 200,
          receipts: {
            "t-a" => { status: "ok", message: nil, error: nil },
            "t-b" => { status: "ok", message: nil, error: nil },
          },
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [first.id, second.id]),
        )
      end

      it "fans out both endpoints in one send batch" do
        expect(result.success?).to eq(true)
        expect(http_client).to have_received(:send_messages) { |messages| expect(messages.size).to eq(2) }
      end
    end

    context "when a ticket reports DeviceNotRegistered" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[eeee5555]") }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{
            status: "error",
            id: nil,
            message: "gone",
            error: "DeviceNotRegistered",
          }],
        )
        allow(CommandTower::Messaging::Endpoints).to receive(:mark_invalid).and_call_original
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "marks the endpoint invalid and returns terminal_failure" do
        expect(result.terminal_failure?).to eq(true)
        expect(result.error_code).to eq("expo_device_invalid")
        expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid).with(
          owner_user_id: user.id,
          endpoint_id: endpoint.id,
        )
        expect(endpoint.reload.lifecycle_state).to eq("invalid")
      end
    end

    context "when a receipt reports DeviceNotRegistered" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[ffff6666]") }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-x", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).and_return(
          ok: true,
          status_code: 200,
          receipts: {
            "ticket-x" => {
              status: "error",
              message: "gone",
              error: "DeviceNotRegistered",
            },
          },
        )
        allow(CommandTower::Messaging::Endpoints).to receive(:mark_invalid).and_call_original
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "marks invalid from receipt DeviceNotRegistered" do
        expect(result.terminal_failure?).to eq(true)
        expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid)
        expect(endpoint.reload.lifecycle_state).to eq("invalid")
      end
    end

    context "when ticket is ok and receipt is pending" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[gggg7777]") }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-pending", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).and_return(
          ok: true,
          status_code: 200,
          receipts: {},
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "treats missing receipts as success without failing the delivery" do
        expect(result.success?).to eq(true)
        expect(result.provider_message_id).to eq("ticket-pending")
      end
    end
  end
end
