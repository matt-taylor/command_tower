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
    lambda do |endpoint_ids:, attempt_id: 3, **presentation|
      rendered = CommandTower::Messaging::Rendering::RenderedPushPayload.build(
        recipient_address: endpoint_ids.first.to_s,
        title: "Hello",
        body: "World",
        deep_link: "pickem://home",
        **presentation,
      )
      CommandTower::Messaging::Execution::AdapterRequest.build(
        channel_delivery_id: delivery.id,
        communication_id: communication.id,
        channel_key: "push",
        attempt_id:,
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
      supported_interruption_levels: supported_levels,
    )
  end
  let(:supported_levels) { %w[normal] }
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

    context "when mapping presentation fields onto the Expo message" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[pres0001]") }
      let(:presentation) { {} }
      let(:sent_message) do
        messages = nil
        allow(http_client).to receive(:send_messages) do |sent|
          messages = sent
          { ok: true, status_code: 200, tickets: [{ status: "ok", id: "ticket-pres", message: nil, error: nil }] }
        end
        allow(http_client).to receive(:get_receipts).with(["ticket-pres"]).and_return(
          ok: true,
          status_code: 200,
          receipts: { "ticket-pres" => { status: "ok", message: nil, error: nil } },
        )
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id], **presentation),
        )
        messages.first
      end

      context "with a default host and a payload without presentation fields" do
        it "sends exactly today's message" do
          expect(sent_message).to eq(
            "to" => "ExponentPushToken[pres0001]",
            "title" => "Hello",
            "body" => "World",
            "sound" => "default",
            "data" => { "deepLink" => "pickem://home" },
          )
        end
      end

      context "with a custom sound asset" do
        let(:presentation) { { sound: "chime.wav" } }

        it "sends the asset as the Expo sound" do
          expect(sent_message["sound"]).to eq("chime.wav")
        end
      end

      context "with time sensitive urgency and the default supported levels" do
        let(:presentation) { { urgency: "time_sensitive" } }

        it "sends no interruption level" do
          expect(sent_message).not_to have_key("interruptionLevel")
        end
      end

      context "with time sensitive urgency and time sensitive supported" do
        let(:supported_levels) { %w[normal time_sensitive] }
        let(:presentation) { { urgency: "time_sensitive" } }

        it "sends the hyphenated Expo level" do
          expect(sent_message["interruptionLevel"]).to eq("time-sensitive")
        end
      end

      context "with critical urgency and only time sensitive supported" do
        let(:supported_levels) { %w[normal time_sensitive] }
        let(:presentation) { { urgency: "critical" } }

        it "degrades to time-sensitive" do
          expect(sent_message["interruptionLevel"]).to eq("time-sensitive")
        end
      end

      context "with critical urgency and critical supported" do
        let(:supported_levels) { %w[normal time_sensitive critical] }
        let(:presentation) { { urgency: "critical" } }

        it "sends critical" do
          expect(sent_message["interruptionLevel"]).to eq("critical")
        end
      end

      context "with normal urgency and every level supported" do
        let(:supported_levels) { %w[normal time_sensitive critical] }

        it "sends no interruption level" do
          expect(sent_message).not_to have_key("interruptionLevel")
        end
      end

      context "with a thread id" do
        let(:presentation) { { thread_id: "pickem.league.1.period.2" } }

        it "sends it as threadId and leaves data unchanged" do
          expect(sent_message["threadId"]).to eq("pickem.league.1.period.2")
          expect(sent_message["data"]).to eq("deepLink" => "pickem://home")
        end
      end

      context "without a thread id" do
        it "omits threadId" do
          expect(sent_message).not_to have_key("threadId")
        end
      end

      context "with a badge of zero" do
        let(:presentation) { { badge: 0 } }

        it "sends the zero badge" do
          expect(sent_message["badge"]).to eq(0)
        end
      end

      context "with a positive badge, a sound, a level, and a thread" do
        let(:supported_levels) { %w[normal time_sensitive] }
        let(:presentation) do
          {
            badge: 2,
            sound: "chime.wav",
            urgency: "time_sensitive",
            thread_id: "pickem.league.1.period.2",
          }
        end

        it "sends the badge beside the presentation fields and leaves data unchanged" do
          expect(sent_message["badge"]).to eq(2)
          expect(sent_message["sound"]).to eq("chime.wav")
          expect(sent_message["interruptionLevel"]).to eq("time-sensitive")
          expect(sent_message["threadId"]).to eq("pickem.league.1.period.2")
          expect(sent_message["data"]).to eq("deepLink" => "pickem://home")
        end
      end

      context "with presentation fields and no badge" do
        let(:supported_levels) { %w[normal time_sensitive] }
        let(:presentation) do
          { sound: "chime.wav", urgency: "time_sensitive", thread_id: "pickem.league.1.period.2" }
        end

        it "omits badge and keeps the other presentation fields" do
          expect(sent_message).not_to have_key("badge")
          expect(sent_message["sound"]).to eq("chime.wav")
          expect(sent_message["interruptionLevel"]).to eq("time-sensitive")
          expect(sent_message["threadId"]).to eq("pickem.league.1.period.2")
          expect(sent_message["data"]).to eq("deepLink" => "pickem://home")
        end
      end
    end

    context "when a live standalone inbox item exists" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[inbox1111]") }
      let!(:inbox_item) { create(:messaging_inbox_item, communication:) }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-item", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).with(["ticket-item"]).and_return(
          ok: true,
          status_code: 200,
          receipts: { "ticket-item" => { status: "ok", message: nil, error: nil } },
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "adds the item id as both inbox identifiers and keeps the token out of data" do
        result

        expect(http_client).to have_received(:send_messages) do |messages|
          data = messages.first["data"]
          expect(data).to eq(
            "deepLink" => "pickem://home",
            "inboxItemId" => inbox_item.id.to_s,
            "inboxEntryId" => inbox_item.id.to_s,
          )
          expect(data.values).not_to include("ExponentPushToken[inbox1111]")
        end
      end
    end

    context "when the live item belongs to a conversation" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[inbox2222]") }
      let!(:inbox_item) { create(:messaging_inbox_item, communication:) }

      before do
        communication.update!(conversation_key: "week-5", conversation_title: "Week 5")
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-conv", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).with(["ticket-conv"]).and_return(
          ok: true,
          status_code: 200,
          receipts: { "ticket-conv" => { status: "ok", message: nil, error: nil } },
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "uses the conversation key as inboxEntryId" do
        result

        expect(http_client).to have_received(:send_messages) do |messages|
          expect(messages.first["data"]).to include(
            "inboxItemId" => inbox_item.id.to_s,
            "inboxEntryId" => "week-5",
          )
        end
      end
    end

    context "when the inbox item is archived" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[inbox3333]") }
      let!(:inbox_item) { create(:messaging_inbox_item, :archived, communication:) }

      before do
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-arch", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).with(["ticket-arch"]).and_return(
          ok: true,
          status_code: 200,
          receipts: { "ticket-arch" => { status: "ok", message: nil, error: nil } },
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "still includes the inbox identifiers" do
        result

        expect(http_client).to have_received(:send_messages) do |messages|
          expect(messages.first["data"]).to include(
            "inboxItemId" => inbox_item.id.to_s,
            "inboxEntryId" => inbox_item.id.to_s,
          )
        end
      end
    end

    context "when the inbox item is deleted" do
      let!(:endpoint) { create_verified_push!.call(address: "ExponentPushToken[inbox4444]") }

      before do
        create(:messaging_inbox_item, :deleted, communication:)
        allow(http_client).to receive(:send_messages).and_return(
          ok: true,
          status_code: 200,
          tickets: [{ status: "ok", id: "ticket-del", message: nil, error: nil }],
        )
        allow(http_client).to receive(:get_receipts).with(["ticket-del"]).and_return(
          ok: true,
          status_code: 200,
          receipts: { "ticket-del" => { status: "ok", message: nil, error: nil } },
        )
      end

      subject(:result) do
        described_class.new(configuration: configured, http_client:).call(
          request: build_request.call(endpoint_ids: [endpoint.id]),
        )
      end

      it "omits inbox identifiers" do
        result

        expect(http_client).to have_received(:send_messages) do |messages|
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

    context "when recording provider_metadata" do
      let!(:first) { create_verified_push!.call(address: "ExponentPushToken[meta0001]") }
      let!(:second) { create_verified_push!.call(address: "ExponentPushToken[meta0002]") }
      let(:ticket_ok_a) { { status: "ok", id: "t-a", message: nil, error: nil } }
      let(:ticket_ok_b) { { status: "ok", id: "t-b", message: nil, error: nil } }
      let(:ticket_gone) { { status: "error", id: nil, message: "gone", error: "DeviceNotRegistered" } }
      let(:ticket_too_big) { { status: "error", id: nil, message: "big", error: "MessageTooBig" } }
      let(:receipts_ok) do
        {
          ok: true,
          status_code: 200,
          receipts: {
            "t-a" => { status: "ok", message: nil, error: nil },
            "t-b" => { status: "ok", message: nil, error: nil },
          },
        }
      end
      let(:endpoint_ids) { [first.id, second.id] }
      let(:secret_reader) { CommandTower::Messaging::Endpoints::SecretReader }
      let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a, ticket_ok_b] } }
      let(:receipts_response) { receipts_ok }
      let(:metadata) { result.provider_metadata }
      let(:endpoints) { metadata.dig("expo", "endpoints") }

      subject(:result) do
        described_class.new(configuration: configured, http_client:, secret_reader:).call(
          request: build_request.call(endpoint_ids:),
        )
      end

      before do
        allow(http_client).to receive_messages(send_messages: send_response, get_receipts: receipts_response)
      end

      context "when both tickets and receipts are ok" do
        it "records ok tickets and ok receipts without changing the outcome" do
          expect(result.success?).to eq(true)
          expect(result.provider_message_id).to eq("t-a")
          expect(endpoints).to eq(
            [
              { "endpoint_id" => first.id, "ticket_id" => "t-a", "ticket_status" => "ok", "receipt_status" => "ok" },
              { "endpoint_id" => second.id, "ticket_id" => "t-b", "ticket_status" => "ok", "receipt_status" => "ok" },
            ],
          )
        end
      end

      context "when one ticket is ok and the other is rejected" do
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a, ticket_too_big] } }
        let(:receipts_response) do
          { ok: true, status_code: 200, receipts: { "t-a" => { status: "ok", message: nil, error: nil } } }
        end

        it "keeps the delivery successful and records the rejected device" do
          expect(result.success?).to eq(true)
          expect(result.provider_message_id).to eq("t-a")
          expect(endpoints.last).to eq(
            "endpoint_id" => second.id,
            "ticket_status" => "error",
            "receipt_status" => "unchecked",
            "error_code" => "expo_rejected",
          )
        end
      end

      context "when Expo returns fewer tickets than messages" do
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a] } }
        let(:receipts_response) do
          { ok: true, status_code: 200, receipts: { "t-a" => { status: "ok", message: nil, error: nil } } }
        end

        it "terminals with submission_uncertain when a ticket is missing after HTTP success" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("submission_uncertain")
          expect(result.provider_message_id).to eq("t-a")
          expect(endpoints.pluck("ticket_status")).to eq(%w[ok missing])
          expect(endpoints.last).to eq(
            "endpoint_id" => second.id,
            "ticket_status" => "missing",
            "receipt_status" => "unchecked",
            "error_code" => "submission_uncertain",
          )
        end
      end

      context "when a receipt reports DeviceNotRegistered" do
        let(:endpoint_ids) { [first.id] }
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a] } }
        let(:receipts_response) do
          {
            ok: true,
            status_code: 200,
            receipts: { "t-a" => { status: "error", message: "gone", error: "DeviceNotRegistered" } },
          }
        end

        it "records the receipt error on an ok ticket" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("expo_device_invalid")
          expect(endpoints).to eq(
            [
              {
                "endpoint_id" => first.id,
                "ticket_id" => "t-a",
                "ticket_status" => "ok",
                "receipt_status" => "error",
                "error_code" => "expo_device_invalid",
              },
            ],
          )
        end
      end

      context "when the receipt is absent" do
        let(:endpoint_ids) { [first.id] }
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a] } }
        let(:receipts_response) { { ok: true, status_code: 200, receipts: {} } }

        it "records the receipt as pending" do
          expect(result.success?).to eq(true)
          expect(endpoints.first.slice("ticket_status", "receipt_status")).to eq(
            "ticket_status" => "ok",
            "receipt_status" => "pending",
          )
        end
      end

      context "when the receipt fetch returns a non-success response" do
        let(:endpoint_ids) { [first.id] }
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a] } }
        let(:receipts_response) { { ok: false, status_code: 503, receipts: {} } }

        it "records the receipt as pending and keeps the delivery successful" do
          expect(result.success?).to eq(true)
          expect(result.provider_message_id).to eq("t-a")
          expect(endpoints.first["receipt_status"]).to eq("pending")
        end
      end

      context "when the whole send request fails with a server error" do
        let(:send_response) { { ok: false, status_code: 503, tickets: [] } }

        it "terminals with submission_uncertain for server errors after HTTP dispatch" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("submission_uncertain")
          expect(result.provider_message_id).to be_nil
          expect(endpoints).to eq(
            [first.id, second.id].map do |id|
              {
                "endpoint_id" => id,
                "ticket_status" => "missing",
                "receipt_status" => "unchecked",
                "error_code" => "submission_uncertain",
              }
            end,
          )
        end
      end

      context "when the whole send request is rejected" do
        let(:send_response) { { ok: false, status_code: 400, tickets: [] } }

        it "records the mapped error code on each submitted endpoint" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("expo_rejected")
          expect(endpoints.pluck("error_code")).to eq(%w[expo_rejected expo_rejected])
        end
      end

      context "when every ticket reports DeviceNotRegistered" do
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_gone, ticket_gone] } }

        it "records error tickets and terminal outcome" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("expo_device_invalid")
          expect(endpoints.map { |entry| entry.slice("ticket_status", "receipt_status", "error_code") }).to all(
            eq(
              "ticket_status" => "error",
              "receipt_status" => "unchecked",
              "error_code" => "expo_device_invalid",
            ),
          )
        end
      end

      context "when one endpoint token cannot be read" do
        let(:secret_reader) { class_double(CommandTower::Messaging::Endpoints::SecretReader) }
        let(:send_response) { { ok: true, status_code: 200, tickets: [ticket_ok_a] } }
        let(:receipts_response) do
          { ok: true, status_code: 200, receipts: { "t-a" => { status: "ok", message: nil, error: nil } } }
        end

        before do
          allow(secret_reader).to receive(:read!)
            .with(owner_user_id: user.id, endpoint_id: first.id)
            .and_raise(CommandTower::Messaging::Endpoints::NotFoundError)
          allow(secret_reader).to receive(:read!)
            .with(owner_user_id: user.id, endpoint_id: second.id)
            .and_return("ExponentPushToken[meta0002]")
        end

        it "records the unreadable endpoint without ticket or receipt status" do
          expect(result.success?).to eq(true)
          expect(endpoints.first).to eq("endpoint_id" => first.id, "error_code" => "recipient_missing")
          expect(endpoints.last).to include("endpoint_id" => second.id, "ticket_status" => "ok")
        end
      end

      context "when receipt fetch raises after tickets were received" do
        before { allow(http_client).to receive(:get_receipts).and_raise(Timeout::Error) }

        it "keeps the ok tickets and a successful delivery outcome" do
          expect(result.success?).to eq(true)
          expect(result.provider_message_id).to eq("t-a")
          expect(endpoints).to eq(
            [
              {
                "endpoint_id" => first.id, "ticket_id" => "t-a",
                "ticket_status" => "ok", "receipt_status" => "pending"
              },
              {
                "endpoint_id" => second.id, "ticket_id" => "t-b",
                "ticket_status" => "ok", "receipt_status" => "pending"
              },
            ],
          )
        end
      end

      context "when the send raises" do
        before { allow(http_client).to receive(:send_messages).and_raise(Timeout::Error) }

        it "terminals with submission_uncertain when the send raises after dispatch may have started" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("submission_uncertain")
          expect(result.provider_metadata).to be_nil
        end
      end

      context "when an exception happens before any endpoint is submitted" do
        let(:secret_reader) { class_double(CommandTower::Messaging::Endpoints::SecretReader) }

        before { allow(secret_reader).to receive(:read!).and_raise(StandardError) }

        it "terminals with submission_uncertain when nothing was submitted" do
          expect(result.terminal_failure?).to eq(true)
          expect(result.error_code).to eq("submission_uncertain")
          expect(result.provider_metadata).to be_nil
        end
      end

      context "when serializing the recorded metadata" do
        it "never contains a push token" do
          expect(metadata.to_json).not_to include("ExponentPushToken")
        end
      end
    end

    context "when retrying across attempts" do
      let!(:endpoint_a) { create_verified_push!.call(address: "ExponentPushToken[retry0001]") }
      let!(:endpoint_b) { create_verified_push!.call(address: "ExponentPushToken[retry0002]") }
      let!(:endpoint_c) { create_verified_push!.call(address: "ExponentPushToken[retry0003]") }
      let(:token_a) { "ExponentPushToken[retry0001]" }
      let(:token_b) { "ExponentPushToken[retry0002]" }
      let(:token_c) { "ExponentPushToken[retry0003]" }
      let(:sent_tokens) { [] }
      let(:ok_ticket) { ->(id) { { status: "ok", id:, message: nil, error: nil } } }
      let(:too_big_ticket) { { status: "error", id: nil, message: "big", error: "MessageTooBig" } }
      let(:gone_ticket) { { status: "error", id: nil, message: "gone", error: "DeviceNotRegistered" } }
      let(:send_ok) { ->(tickets) { { ok: true, status_code: 200, tickets: } } }
      let(:whole_request_failure) { ->(code) { { ok: false, status_code: code, tickets: [] } } }
      let(:meta_entries) { ->(outcome) { outcome.provider_metadata.dig("expo", "endpoints") } }
      let(:run_attempt) do
        lambda do |ids, response|
          allow(http_client).to receive(:send_messages) do |messages|
            sent_tokens << messages.pluck("to")
            raise response if response.is_a?(Class)

            response
          end
          attempt = CommandTower::Messaging::DeliveryAttempt.create!(
            channel_delivery: delivery,
            status: "started",
            started_at: Time.current,
          )
          outcome = described_class.new(configuration: configured, http_client:).call(
            request: build_request.call(endpoint_ids: ids, attempt_id: attempt.id),
          )
          attempt_status =
            case outcome.outcome
            when :success then "succeeded"
            when :terminal_failure then "failed_terminal"
            else "failed_retryable"
            end
          attempt.update!(
            status: attempt_status,
            finished_at: Time.current,
            provider_metadata: outcome.provider_metadata,
            error_code: outcome.error_code,
          )
          outcome
        end
      end

      before do
        allow(http_client).to receive(:get_receipts) do |ticket_ids|
          {
            ok: true,
            status_code: 200,
            receipts: ticket_ids.index_with { { status: "ok", message: nil, error: nil } },
          }
        end
        allow(CommandTower::Messaging::Endpoints).to receive(:mark_invalid).and_call_original
      end

      context "with a single attempt that mixes outcomes" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }

        context "when one ticket is ok and the other has no ticket" do
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }

          it "terminals with submission_uncertain and records the accepted ticket" do
            expect(first_result.terminal_failure?).to eq(true)
            expect(first_result.error_code).to eq("submission_uncertain")
            expect(first_result.provider_message_id).to eq("t-a")
            expect(meta_entries.call(first_result).pluck("ticket_status")).to eq(%w[ok missing])
          end
        end

        context "when one ticket is ok and the other is terminally rejected" do
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a"), too_big_ticket])) }

          it "is a success" do
            expect(first_result.success?).to eq(true)
            expect(first_result.provider_message_id).to eq("t-a")
          end
        end

        context "when every ticket is terminally rejected" do
          let!(:first_result) { run_attempt.call(ids, send_ok.call([too_big_ticket, gone_ticket])) }

          it "is terminal with the first error code" do
            expect(first_result.terminal_failure?).to eq(true)
            expect(first_result.error_code).to eq("expo_rejected")
          end
        end

        context "when no ticket comes back for any device" do
          let!(:first_result) { run_attempt.call(ids, send_ok.call([])) }

          it "is terminal with submission_uncertain" do
            expect(first_result.terminal_failure?).to eq(true)
            expect(first_result.error_code).to eq("submission_uncertain")
            expect(first_result.provider_message_id).to be_nil
          end
        end

        context "when both tickets are ok" do
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a"), ok_ticket.call("t-b")])) }

          it "is a success" do
            expect(first_result.success?).to eq(true)
            expect(first_result.provider_message_id).to eq("t-a")
          end
        end
      end

      context "when a partial ticket response is never retried across attempts" do
        let(:ids) { [endpoint_a.id, endpoint_b.id, endpoint_c.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }

        it "terminals the first attempt without adapter-level follow-up sends" do
          expect(first_result.terminal_failure?).to eq(true)
          expect(sent_tokens).to eq([[token_a, token_b, token_c]])
        end
      end

      context "when history already records an accepted ticket from a partial attempt" do
        let(:ids) { [endpoint_a.id, endpoint_b.id, endpoint_c.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
        let!(:second_result) do
          run_attempt.call(ids, send_ok.call([ok_ticket.call("t-b"), ok_ticket.call("t-c")]))
        end

        it "skips devices that already have an accepted ticket in history" do
          expect(second_result.success?).to eq(true)
          expect(sent_tokens.last).to eq([token_b, token_c])
        end
      end

      [503, 429].each do |status_code|
        context "across three attempts with a whole-request #{status_code} on the second" do
          let(:ids) { [endpoint_a.id, endpoint_b.id] }
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
          let!(:second_result) { run_attempt.call(ids, whole_request_failure.call(status_code)) }
          let!(:third_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-b")])) }

          it "terminals the whole-request failure with submission_uncertain" do
            expect(second_result.terminal_failure?).to eq(true)
            expect(second_result.error_code).to eq("submission_uncertain")
            expect(second_result.provider_message_id).to be_nil
            expect(meta_entries.call(second_result)).to eq(
              [
                {
                  "endpoint_id" => endpoint_b.id,
                  "ticket_status" => "missing",
                  "receipt_status" => "unchecked",
                  "error_code" => "submission_uncertain",
                },
              ],
            )
          end

          it "does not resend the accepted device on the uncertain attempt" do
            expect(sent_tokens).to eq([[token_a, token_b], [token_b], [token_b]])
            expect(third_result.success?).to eq(true)
            expect(third_result.provider_message_id).to eq("t-b")
          end
        end
      end

      context "when a device with a terminal ticket error is not resent" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([too_big_ticket])) }
        let!(:second_result) { run_attempt.call(ids, send_ok.call([])) }
        let!(:third_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-b")])) }

        it "sends only the unsettled device on every retry" do
          expect(sent_tokens).to eq([[token_a, token_b], [token_b], [token_b]])
        end

        it "terminals missing-ticket outcomes and only succeeds once the unsettled device accepts" do
          expect(first_result.terminal_failure?).to eq(true)
          expect(second_result.terminal_failure?).to eq(true)
          expect(third_result.success?).to eq(true)
          expect(third_result.provider_message_id).to eq("t-b")
          expect(meta_entries.call(third_result).pluck("endpoint_id")).to eq([endpoint_b.id])
        end
      end

      context "when a device was reported as DeviceNotRegistered earlier" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([gone_ticket])) }
        let!(:second_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-b")])) }

        it "does not resend or invalidate that device again" do
          expect(sent_tokens).to eq([[token_a, token_b], [token_b]])
          expect(second_result.success?).to eq(true)
          expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid)
            .with(owner_user_id: user.id, endpoint_id: endpoint_a.id).once
        end
      end

      context "when every eligible device is already settled" do
        context "with only terminally rejected devices" do
          let(:ids) { [endpoint_a.id] }
          let!(:first_result) { run_attempt.call(ids, send_ok.call([gone_ticket])) }
          let!(:second_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("unused")])) }

          it "is terminal with the recorded error code and does not call Expo" do
            expect(first_result.terminal_failure?).to eq(true)
            expect(second_result.terminal_failure?).to eq(true)
            expect(second_result.error_code).to eq("expo_device_invalid")
            expect(second_result.provider_metadata).to be_nil
            expect(sent_tokens.size).to eq(1)
          end
        end

        context "with an accepted device and a rejected device" do
          let(:ids) { [endpoint_a.id, endpoint_b.id] }
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a"), too_big_ticket])) }
          let!(:second_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("unused")])) }

          it "succeeds with the earlier ticket and does not call Expo" do
            expect(second_result.success?).to eq(true)
            expect(second_result.provider_message_id).to eq("t-a")
            expect(second_result.provider_metadata).to be_nil
            expect(sent_tokens.size).to eq(1)
          end
        end

        context "with only accepted devices" do
          let(:ids) { [endpoint_a.id] }
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
          let!(:second_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("unused")])) }

          it "succeeds with the earlier ticket and does not call Expo" do
            expect(second_result.success?).to eq(true)
            expect(second_result.provider_message_id).to eq("t-a")
            expect(sent_tokens.size).to eq(1)
          end
        end
      end

      context "when a terminal ticket error arrives after another device was accepted" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
        let!(:second_result) { run_attempt.call(ids, send_ok.call([gone_ticket])) }

        it "stays a success, invalidates the device, and falls back to the earlier ticket id" do
          expect(sent_tokens).to eq([[token_a, token_b], [token_b]])
          expect(second_result.success?).to eq(true)
          expect(second_result.provider_message_id).to eq("t-a")
          expect(meta_entries.call(second_result).pluck("endpoint_id", "ticket_status", "error_code"))
            .to eq([[endpoint_b.id, "error", "expo_device_invalid"]])
          expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid)
            .with(owner_user_id: user.id, endpoint_id: endpoint_b.id).once
        end
      end

      context "when the whole request is rejected on a retry after another device was accepted" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
        let!(:second_result) { run_attempt.call(ids, whole_request_failure.call(400)) }

        it "stays terminal for the attempt without resending the accepted device" do
          expect(sent_tokens).to eq([[token_a, token_b], [token_b]])
          expect(second_result.terminal_failure?).to eq(true)
          expect(second_result.error_code).to eq("expo_rejected")
          expect(second_result.provider_message_id).to be_nil
        end

        it "records the submitted device and carries the accepted ticket forward" do
          expect(meta_entries.call(second_result)).to eq(
            [
              {
                "endpoint_id" => endpoint_b.id,
                "ticket_status" => "missing",
                "receipt_status" => "unchecked",
                "error_code" => "expo_rejected",
              },
              { "endpoint_id" => endpoint_a.id, "ticket_id" => "t-a", "ticket_status" => "ok" },
            ],
          )
        end
      end

      [401, 403].each do |status_code|
        context "when a retry gets a whole-request #{status_code}" do
          let(:ids) { [endpoint_a.id, endpoint_b.id] }
          let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
          let!(:second_result) { run_attempt.call(ids, whole_request_failure.call(status_code)) }

          it "is terminal and carries the accepted ticket" do
            expect(second_result.terminal_failure?).to eq(true)
            expect(meta_entries.call(second_result).pluck("endpoint_id")).to eq([endpoint_b.id, endpoint_a.id])
          end
        end
      end

      context "when the first attempt gets a whole-request rejection" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }
        let!(:first_result) { run_attempt.call(ids, whole_request_failure.call(400)) }

        it "is terminal with no carried entries" do
          expect(first_result.terminal_failure?).to eq(true)
          expect(meta_entries.call(first_result).pluck("endpoint_id")).to eq([endpoint_a.id, endpoint_b.id])
          expect(meta_entries.call(first_result).pluck("ticket_status")).to eq(%w[missing missing])
        end
      end

      context "when the send raises on a retry after another device was accepted" do
        let(:ids) { [endpoint_a.id, endpoint_b.id] }
        let!(:first_result) { run_attempt.call(ids, send_ok.call([ok_ticket.call("t-a")])) }
        let!(:second_result) { run_attempt.call(ids, Timeout::Error) }

        it "terminals with submission_uncertain without resending the accepted device" do
          expect(second_result.terminal_failure?).to eq(true)
          expect(second_result.error_code).to eq("submission_uncertain")
          expect(sent_tokens).to eq([[token_a, token_b], [token_b]])
        end
      end
    end
  end
end
