# frozen_string_literal: true

RSpec.describe CommandTower::Logging::Subscriber do
  after do
    CommandTower::Current.reset
    described_class.attach!
  end
  let(:workflow_class) do
    Class.new(CommandTower::Workflows::ApplicationWorkflow) do
      retry_strategy :none

      def call(**)
        success(payload: { ok: true }, http_status: :ok)
      end
    end
  end

  before { stub_const("CommandTower::LoggingProbeWorkflow", workflow_class) }

  describe ".attach!" do
    before do
      described_class.attach!
      described_class.attach!
    end

    it { expect(described_class.subscriptions.size).to eq(3) }
  end

  describe "lifecycle materialization" do
    let(:messages) { [] }
    let(:asn) { [] }
    let(:asn_subscriber) do
      bucket = asn
      ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\./) do |name, *_rest|
        bucket << name
      end
    end

    before do
      asn_subscriber
      %i[debug info warn error].each do |level|
        allow(Rails.logger).to receive(level) do |message|
          messages << { level:, message: }
        end
      end
    end

    after { unsubscribe_notifications(asn_subscriber) }

    let(:lifecycle_completed_logs) do
      messages.select do |entry|
        entry[:message].is_a?(Hash) && entry[:message][:event].to_s.end_with?(".completed")
      end
    end

    context "when the workflow succeeds" do
      before do
        CommandTower.with_execution(source: :console, user_id: 9, correlation_id: "corr-log") do
          CommandTower::LoggingProbeWorkflow.call
        end
      end

      let(:started) do
        messages.find { |entry| entry[:message].is_a?(Hash) && entry[:message][:event] == CommandTower::Events::WORKFLOW_STARTED }
      end
      let(:completed) do
        messages.find { |entry| entry[:message].is_a?(Hash) && entry[:message][:event] == CommandTower::Events::WORKFLOW_COMPLETED }
      end

      it "emits the pair and materializes completed success at info, never started" do
        expect(asn).to eq(
          [
            CommandTower::Events::WORKFLOW_STARTED,
            CommandTower::Events::WORKFLOW_COMPLETED
          ]
        )
        expect(started).to be_nil
        expect(completed[:level]).to eq(:info)
        expect(completed[:message][:outcome]).to eq(:success)
        expect(completed[:message][:execution_uuid]).to be_present
        expect(completed[:message][:correlation_id]).to eq("corr-log")
        expect(completed[:message][:user_id]).to eq(9)
        expect(completed[:message][:subject]).to eq("CommandTower::LoggingProbeWorkflow")
        expect(completed[:message]).not_to have_key(:log_lifecycle)
        expect(completed[:message]).not_to have_key(:log_level)
        expect(completed[:message]).not_to have_key(:event_uuid)
        expect(completed[:message]).not_to have_key(:layer)
        expect(completed[:message][:source]).to eq(:console)
      end
    end

    context "when a subclass inherits workflow lifecycle logging" do
      let(:parent_class) do
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          def call(**)
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end
      let(:workflow_class) do
        Class.new(parent_class) do
          retry_strategy :none
        end
      end

      before { CommandTower::LoggingProbeWorkflow.call }

      it "materializes the inherited completed success" do
        expect(lifecycle_completed_logs.map { |entry| entry[:level] }).to eq([:info])
      end
    end

    context "when a subclass disables inherited lifecycle logging" do
      let(:parent_class) do
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          def call(**)
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end
      let(:workflow_class) do
        Class.new(parent_class) do
          retry_strategy :none
          disable_lifecycle_logging!
        end
      end

      before { CommandTower::LoggingProbeWorkflow.call }

      it "does not materialize success" do
        expect(lifecycle_completed_logs).to eq([])
        expect(asn).to include(CommandTower::Events::WORKFLOW_COMPLETED)
      end
    end

    context "when a workflow nests a quiet service" do
      let(:service_class) do
        Class.new(CommandTower::Services::ApplicationService) do
          def call
            context.value = "ok"
          end
        end
      end
      let(:workflow_class) do
        nested = service_class
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          define_method(:call) do |**|
            nested.call
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end

      before do
        stub_const("CommandTower::LoggingProbeService", service_class)
        CommandTower::LoggingProbeWorkflow.call
      end

      it "logs the workflow completed and not the nested service success" do
        expect(lifecycle_completed_logs.map { |entry| entry[:message][:event] }).to eq([CommandTower::Events::WORKFLOW_COMPLETED])
        expect(asn).to include(CommandTower::Events::SERVICE_STARTED, CommandTower::Events::SERVICE_COMPLETED)
      end
    end

    context "when the workflow fails without opt-in" do
      let(:workflow_class) do
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          def call(**)
            failure(errors: [CommandTower::Errors::UnauthorizedError.new], http_status: :unauthorized)
          end
        end
      end

      before { CommandTower::LoggingProbeWorkflow.call }

      let(:completed) { messages.find { |entry| entry[:message].is_a?(Hash) && entry[:message][:outcome] == :failure } }

      it "uses ApplicationError log_level" do
        expect(completed[:level]).to eq(:warn)
        expect(completed[:message]).not_to have_key(:log_level)
      end
    end

    context "when the workflow errors without opt-in" do
      let(:workflow_class) do
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          def call(**)
            raise StandardError, "boom"
          end
        end
      end

      before { CommandTower::LoggingProbeWorkflow.call }

      let(:completed) { messages.find { |entry| entry[:message].is_a?(Hash) && entry[:message][:outcome] == :error } }

      it "logs completed error without the exception message" do
        expect(completed[:level]).to eq(:error)
        expect(completed[:message][:error_class]).to eq("StandardError")
        expect(completed[:message].inspect).not_to include("boom")
      end
    end

    context "when a deferred workflow completes" do
      let(:workflow_class) do
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          def call(**)
            deferred(reason: :provider_cooldown, retry_after: 5)
          end
        end
      end

      before { CommandTower::LoggingProbeWorkflow.call }

      it "materializes deferred completions at info" do
        expect(lifecycle_completed_logs.map { |entry| entry[:message][:outcome] }).to eq([:deferred])
        expect(lifecycle_completed_logs.first[:level]).to eq(:info)
      end
    end

    context "when a service succeeds without opt-in" do
      let(:service_class) do
        Class.new(CommandTower::Services::ApplicationService) do
          def call
            context.value = "ok"
          end
        end
      end

      before do
        stub_const("CommandTower::LoggingProbeService", service_class)
        CommandTower::LoggingProbeService.call
      end

      it "emits without a service completed info line" do
        expect(asn).to include(CommandTower::Events::SERVICE_COMPLETED)
        expect(lifecycle_completed_logs).to eq([])
      end
    end
  end

  describe "silence and publication" do
    let(:asn) { [] }
    let(:asn_subscriber) do
      bucket = asn
      ActiveSupport::Notifications.subscribe(CommandTower::Events::WORKFLOW_COMPLETED) do |name, *_rest|
        bucket << name
      end
    end
    let(:seen) { [] }
    let(:probe_logger) do
      recorder = seen
      logger = ActiveSupport::Logger.new(StringIO.new)
      logger.level = Logger::DEBUG
      logger.formatter = Class.new do
        define_method(:call) do |_severity, _time, _progname, msg|
          recorder << msg
          ""
        end
      end.new
      logger
    end
    let(:workflow_class) do
      Class.new(CommandTower::Workflows::ApplicationWorkflow) do
        retry_strategy :none
        log_lifecycle!

        def call(**)
          success(payload: { ok: true }, http_status: :ok)
        end
      end
    end

    before do
      asn_subscriber
      described_class.logger = probe_logger
    end

    after do
      unsubscribe_notifications(asn_subscriber)
      described_class.logger = nil
    end

    context "when the logger is silenced" do
      before do
        probe_logger.silence do
          CommandTower::LoggingProbeWorkflow.call
        end
      end

      it "still publishes ASN and does not materialize logs" do
        expect(asn).to eq([CommandTower::Events::WORKFLOW_COMPLETED])
        expect(seen).to eq([])
      end
    end

    context "when silence is nested" do
      before do
        probe_logger.silence do
          CommandTower::LoggingProbeWorkflow.call
        end
        CommandTower::LoggingProbeWorkflow.call
      end

      it "restores materialization after silence" do
        expect(seen.count { |message| message.is_a?(Hash) && message[:event] == CommandTower::Events::WORKFLOW_COMPLETED }).to eq(1)
      end
    end
  end

  describe "semantic categories" do
    let(:messages) { [] }

    before do
      %i[debug info warn error].each do |level|
        allow(Rails.logger).to receive(level) { |message| messages << { level:, message: } }
      end
    end

    context "when a log event is published from a quiet workflow" do
      let(:workflow_class) do
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none
          disable_lifecycle_logging!

          def call(**)
            log_info("explicit")
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end

      before { CommandTower::LoggingProbeWorkflow.call }

      let(:log_event) { messages.find { |item| item[:message].is_a?(Hash) && item[:message][:event] == "command_tower.log.info" } }

      it "materializes the explicit log and not lifecycle success" do
        expect(log_event[:level]).to eq(:info)
        expect(log_event[:message][:message]).to eq("explicit")
        expect(messages).not_to include(
          a_hash_including(message: a_hash_including(event: CommandTower::Events::WORKFLOW_COMPLETED, outcome: :success))
        )
      end
    end

    context "when a log event is published" do
      before do
        CommandTower::Events.publish(category: :log, name: :warn, payload: { message: "token mismatch" })
      end

      let(:log_event) { messages.find { |item| item[:message].is_a?(Hash) && item[:message][:event] == "command_tower.log.warn" } }

      it "materializes at the named severity" do
        expect(log_event[:level]).to eq(:warn)
        expect(log_event[:message][:message]).to eq("token mismatch")
      end
    end

    context "when a messaging event is published" do
      before do
        CommandTower::Events.publish(category: :messaging, name: "inbox.viewed", payload: { log_level: :info })
      end

      let(:messaging_event) do
        messages.find { |item| item[:message].is_a?(Hash) && item[:message][:event] == "command_tower.messaging.inbox.viewed" }
      end

      it "materializes messaging telemetry" do
        expect(messaging_event[:level]).to eq(:info)
      end
    end

    context "when an audit event is published" do
      before do
        CommandTower::Events.publish(category: :audit, name: :wager_transition, payload: { wager_id: 1 })
      end

      it "does not materialize" do
        expect(messages).to eq([])
      end
    end
  end

  describe "projection isolation" do
    let(:asn_payloads) { [] }
    let(:asn_subscriber) do
      bucket = asn_payloads
      ActiveSupport::Notifications.subscribe(CommandTower::Events::WORKFLOW_COMPLETED) do |_name, _s, _f, _id, payload|
        bucket << payload.dup
      end
    end
    let(:messages) { [] }

    before do
      asn_subscriber
      allow(Rails.logger).to receive(:info) { |message| messages << message if message.is_a?(Hash) }
      CommandTower.with_execution(source: :console, user_id: 3) { CommandTower::LoggingProbeWorkflow.call }
    end

    after { unsubscribe_notifications(asn_subscriber) }

    let(:asn_completed) { asn_payloads.last }
    let(:log_completed) { messages.find { |message| message[:event] == CommandTower::Events::WORKFLOW_COMPLETED } }

    it "leaves the canonical payload intact for other subscribers" do
      expect(asn_completed).to include(:event_uuid, :layer, :log_lifecycle)
      expect(asn_completed[:source]).to eq(:console)
      expect(log_completed).not_to have_key(:event_uuid)
      expect(log_completed).not_to have_key(:layer)
      expect(log_completed).not_to have_key(:log_lifecycle)
      expect(log_completed[:source]).to eq(:console)
    end
  end

  describe "host formatter authority" do
    let(:seen) { [] }
    let(:probe_logger) do
      recorder = seen
      logger = ActiveSupport::Logger.new(StringIO.new)
      logger.level = Logger::DEBUG
      logger.formatter = Class.new do
        define_method(:call) do |_severity, _time, _progname, msg|
          recorder << msg
          ""
        end
      end.new
      logger
    end
    let(:workflow_class) do
      Class.new(CommandTower::Workflows::ApplicationWorkflow) do
        retry_strategy :none
        log_lifecycle!

        def call(**)
          success(payload: { ok: true }, http_status: :ok)
        end
      end
    end

    before do
      described_class.logger = probe_logger
      CommandTower::LoggingProbeWorkflow.call
    end

    after { described_class.logger = nil }

    it "passes a Hash through the logger formatter" do
      expect(seen).to include(a_hash_including(event: CommandTower::Events::WORKFLOW_COMPLETED, outcome: :success))
    end
  end

  describe "subscriber failure isolation" do
    let(:workflow_class) do
      Class.new(CommandTower::Workflows::ApplicationWorkflow) do
        retry_strategy :none
        log_lifecycle!

        def call(**)
          success(payload: { ok: true }, http_status: :ok)
        end
      end
    end

    before do
      allow(Rails.logger).to receive(:info).and_raise(StandardError, "logger down")
      allow(Rails.logger).to receive(:debug).and_raise(StandardError, "logger down")
      allow(Rails.logger).to receive(:error)
    end

    subject(:result) { CommandTower::LoggingProbeWorkflow.call }

    it "does not convert logging failure into a workflow failure" do
      expect(result).to be_success
    end
  end
end
