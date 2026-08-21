# frozen_string_literal: true

RSpec.describe CommandTower do
  after { CommandTower::Current.reset }

  describe ".with_execution" do
    context "when establishing a rake execution" do
      subject(:result) do
        described_class.with_execution(source: :rake) do
          {
            execution_uuid: CommandTower::Current.execution_uuid,
            correlation_id: CommandTower::Current.correlation_id,
            source: CommandTower::Current.source,
            request_id: CommandTower::Current.request_id,
            causation_id: CommandTower::Current.causation_id,
            user_id: CommandTower::Current.user_id
          }
        end
      end

      it "assigns a fresh execution and correlation id" do
        expect(result[:execution_uuid]).to be_present
        expect(result[:correlation_id]).to eq(result[:execution_uuid])
        expect(result[:source]).to eq(:rake)
        expect(result[:request_id]).to be_nil
        expect(result[:causation_id]).to be_nil
        expect(result[:user_id]).to be_nil
      end
    end

    context "when two executions run sequentially" do
      subject(:uuids) do
        [
          described_class.with_execution(source: :rake) { CommandTower::Current.execution_uuid },
          described_class.with_execution(source: :console) { CommandTower::Current.execution_uuid }
        ]
      end

      it "does not reuse execution_uuid" do
        expect(uuids[0]).not_to eq(uuids[1])
      end
    end

    context "when with_execution is nested" do
      subject(:result) do
        described_class.with_execution(source: :rake) do
          {
            outer: CommandTower::Current.execution_uuid,
            inner: described_class.with_execution(source: :console) { CommandTower::Current.execution_uuid },
            source: CommandTower::Current.source
          }
        end
      end

      it "shares the outer boundary context" do
        expect(result[:inner]).to eq(result[:outer])
        expect(result[:source]).to eq(:rake)
      end
    end

    context "when the block raises" do
      subject(:after_raise) do
        described_class.with_execution(source: :rake) { raise StandardError, "boom" }
      rescue StandardError
        CommandTower::Current.execution_uuid
      end

      it { expect(after_raise).to be_nil }
    end

    context "when the source is invalid" do
      subject(:invoke) { described_class.with_execution(source: :sidekiq) { nil } }

      it "raises" do
        expect { invoke }.to raise_error(ArgumentError, /invalid execution source/)
      end
    end

    context "when a workflow calls a service" do
      let(:service_class) do
        Class.new(CommandTower::Services::ApplicationService) do
          define_method(:call) do
            context.uuid = execution_context.execution_uuid
          end
        end
      end

      let(:workflow_class) do
        nested = service_class
        Class.new(CommandTower::Workflows::ApplicationWorkflow) do
          retry_strategy :none

          define_method(:call) do |**|
            result = nested.call
            success(
              payload: {
                service_uuid: result.data[:uuid],
                workflow_uuid: execution_context.execution_uuid
              },
              http_status: :ok
            )
          end
        end
      end

      subject(:result) do
        described_class.with_execution(source: :console) do
          {
            outcome: workflow_class.call,
            uuid: CommandTower::Current.execution_uuid
          }
        end
      end

      it "shares one execution_uuid" do
        expect(result[:outcome]).to be_success
        expect(result[:outcome].payload[:service_uuid]).to eq(result[:uuid])
        expect(result[:outcome].payload[:workflow_uuid]).to eq(result[:uuid])
      end
    end
  end
end
