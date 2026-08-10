# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::ApplicationWorkflow do
  describe ".call" do
    subject(:invoke) { workflow_class.call }

    context "when retry_strategy is not declared" do
      let(:workflow_class) do
        Class.new(described_class) do
          def call(**)
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end

      it "raises" do
        expect { invoke }.to raise_error(/must declare retry_strategy/)
      end
    end

    context "when an unknown exception is raised" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            raise StandardError, "boom"
          end
        end
      end

      before do
        allow(Rails.logger).to receive(:error)
        invoke
      end

      it "returns a failure WorkflowResult" do
        expect(invoke).to be_failure
      end

      it "normalizes to InternalError" do
        expect(invoke.errors).to contain_exactly(an_instance_of(CommandTower::Errors::InternalError))
      end

      it "uses internal_server_error status" do
        expect(invoke.http_status).to eq(:internal_server_error)
      end

      it "preserves the original exception as cause" do
        expect(invoke.errors.first.cause.message).to eq("boom")
      end

      it "logs the original exception" do
        expect(Rails.logger).to have_received(:error).with(/boom/)
      end
    end

    context "when the workflow succeeds" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            success(payload: { ok: true }, http_status: :ok, meta: { a: 1 })
          end
        end
      end

      it "returns success" do
        expect(invoke).to be_success
        expect(invoke.payload).to eq(ok: true)
        expect(invoke.meta).to eq(a: 1)
      end
    end
  end

  describe ".call_from_job" do
    context "when the workflow succeeds" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end

      subject(:result) { workflow_class.call_from_job }

      it "returns the success result without raising" do
        expect(result).to be_success
      end
    end

    context "when failure does not request job propagation" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            failure(errors: [CommandTower::Errors::InternalError.new], http_status: :internal_server_error)
          end
        end
      end

      subject(:result) { workflow_class.call_from_job }

      it "returns failure without raising" do
        expect(result).to be_failure
      end
    end

    context "when failure requests job propagation" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            failure(
              errors: [CommandTower::Errors::InternalError.new(cause: StandardError.new("boom"))],
              http_status: :internal_server_error,
              meta: { propagate_to_job: true },
            )
          end
        end
      end

      subject(:invoke) { workflow_class.call_from_job }

      it "raises the workflow error for ActiveJob" do
        expect { invoke }.to raise_error(CommandTower::Errors::InternalError)
      end
    end
  end
end
