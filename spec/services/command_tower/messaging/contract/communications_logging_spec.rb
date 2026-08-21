# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Communications, "structured logging" do
  let(:user) { create(:user) }
  let(:log_entries) { [] }

  let(:messaging_entries) do
    log_entries.select { |entry| entry[:payload]["event"].to_s.start_with?("command_tower.messaging") }
  end

  let(:events) do
    messaging_entries.map { |entry| entry[:payload]["event"] }
  end

  let(:payloads) do
    messaging_entries.map { |entry| entry[:payload] }
  end

  before do
    CommandTower::Current.reset
    %i[debug info warn error].each do |level|
      allow(Rails.logger).to receive(level) do |message|
        next unless message.is_a?(Hash)

        log_entries << { level:, payload: message.stringify_keys }
      end
    end
  end

  after { CommandTower::Current.reset }

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

      let(:succeeded_payload) do
        payloads.find { |payload| payload["event"].end_with?(".succeeded") }
      end

      it "emits started and succeeded events" do
        expect(events).to eq(
          %w[
            command_tower.messaging.communications.find.started
            command_tower.messaging.communications.find.succeeded
          ]
        )
      end

      it "includes duration_ms and communication_id on success" do
        expect(succeeded_payload).to include(
          "communication_id" => communication.id,
          "recipient_id" => user.id,
          "duration_ms" => a_kind_of(Integer)
        )
      end

      it "includes Execution Context identifiers" do
        payloads.each do |payload|
          expect(payload).to include(
            "correlation_id" => a_string_matching(/.+/),
            "messaging_operation" => "communications.find",
            "event" => a_string_matching(/\Acommand_tower\.messaging\.communications\.find\./)
          )
        end
        expect(messaging_entries.map { |entry| entry[:level] }.uniq).to eq([:info])
      end

      it "uses a stable generated correlation_id within the call" do
        expect(payloads.map { |payload| payload["correlation_id"] }.uniq.size).to eq(1)
      end
    end

    context "when Current.request_id is set" do
      before do
        CommandTower::Current.request_id = "req_test_123"
        described_class.find(request)
      end

      it "propagates the ambient request_id as correlation_id" do
        expect(payloads.map { |payload| payload["correlation_id"] }).to all(eq("req_test_123"))
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

      let(:failed_payload) { payloads.find { |payload| payload["event"].end_with?(".failed") } }

      let(:failed_entry) { messaging_entries.find { |entry| entry[:payload]["event"].end_with?(".failed") } }

      it "emits failed at warn and re-raises NotFoundError" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Contract::NotFoundError)
        expect(failed_entry[:level]).to eq(:warn)
        expect(failed_payload["error_code"]).to eq("not_found")
      end
    end

    context "when the logger raises" do
      before do
        allow(Rails.logger).to receive(:info).and_raise(StandardError, "logger down")
        allow(Rails.logger).to receive(:error)
      end

      subject(:result) { described_class.find(request) }

      it "still completes the contract operation" do
        expect(result).to be_a(CommandTower::Messaging::Contract::Results::CommunicationResult)
        expect(result.id).to eq(communication.id)
      end
    end
  end
end
