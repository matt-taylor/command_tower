# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Communications, "structured logging" do
  let(:user) { create(:user) }
  let(:log_entries) { [] }

  let(:parse_json) do
    lambda do |message|
      JSON.parse(message)
    rescue JSON::ParserError
      nil
    end
  end

  let(:messaging_entries) do
    log_entries.select { |entry| entry[:payload]&.dig("component") == "command_tower.messaging" }
  end

  let(:events) do
    messaging_entries.map { |entry| entry[:payload]["event"] }
  end

  let(:payloads) do
    messaging_entries.map { |entry| entry[:payload] }
  end

  before do
    CommandTower::Current.reset
    %i[info warn error].each do |level|
      allow(Rails.logger).to receive(level) do |message|
        log_entries << { level:, payload: parse_json.call(message) }
      end
    end
  end

  after do
    CommandTower::Current.reset
  end

  describe ".find" do
    let!(:communication) do
      create(:messaging_communication, :with_destination_plan, :with_inbox_item, user:)
    end
    let(:request) do
      CommandTower::Messaging::Contract::Requests::FindCommunication.build(
        communication_id: communication.id,
        recipient_id: user.id,
      )
    end

    context "when the find succeeds" do
      before { described_class.find(request) }

      let(:succeeded_payload) { payloads.find { |p| p["event"].end_with?(".succeeded") } }

      it "emits started and succeeded events" do
        expect(events).to eq(
          %w[
            messaging.communications.find.started
            messaging.communications.find.succeeded
          ],
        )
      end

      it "includes duration_ms and communication_id on success" do
        expect(succeeded_payload).to include(
          "communication_id" => communication.id,
          "recipient_id" => user.id,
          "duration_ms" => a_kind_of(Integer),
        )
      end

      it "includes required envelope fields" do
        payloads.each do |payload|
          expect(payload).to include(
            "component" => "command_tower.messaging",
            "correlation_id" => a_string_matching(/.+/),
            "messaging_operation" => "communications.find",
            "event" => a_string_matching(/\Amessaging\.communications\.find\./),
            "level" => "info",
            "timestamp" => a_string_matching(/.+/),
          )
        end
      end

      it "uses a stable generated correlation_id within the call" do
        expect(payloads.map { |p| p["correlation_id"] }.uniq.size).to eq(1)
      end
    end

    context "when Current.request_id is set" do
      before do
        CommandTower::Current.request_id = "req_test_123"
        described_class.find(request)
      end

      it "propagates the ambient request_id as correlation_id" do
        expect(payloads.map { |p| p["correlation_id"] }).to all(eq("req_test_123"))
      end
    end

    context "when the communication is not found" do
      let(:request) do
        CommandTower::Messaging::Contract::Requests::FindCommunication.build(
          communication_id: communication.id + 100_000,
        )
      end

      subject(:invoke) { described_class.find(request) }

      before do
        invoke
      rescue CommandTower::Messaging::Contract::NotFoundError
      end

      let(:failed_payload) { payloads.find { |p| p["event"].end_with?(".failed") } }

      it "emits failed at warn and re-raises NotFoundError" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Contract::NotFoundError)
        expect(failed_payload["level"]).to eq("warn")
        expect(failed_payload["error_code"]).to eq("not_found")
      end
    end

    context "when the logger raises" do
      before do
        allow(Rails.logger).to receive(:info).and_raise(StandardError, "logger down")
      end

      subject(:result) { described_class.find(request) }

      it "still completes the contract operation" do
        expect(result).to be_a(CommandTower::Messaging::Contract::Results::CommunicationResult)
        expect(result.id).to eq(communication.id)
      end
    end
  end
end
