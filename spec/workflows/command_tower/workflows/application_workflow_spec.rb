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

      it "does not log the exception message as a parallel path" do
        expect(Rails.logger).to have_received(:error).with(hash_including(outcome: :error, error_class: "StandardError"))
        expect(Rails.logger).not_to have_received(:error).with(/boom/)
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

    context "when an unexpected exception is raised" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            raise StandardError, "boom"
          end
        end
      end

      it "re-raises instead of swallowing" do
        expect { workflow_class.call_from_job }.to raise_error(StandardError, "boom")
      end
    end

    context "when retry_strategy is :sidekiq" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :sidekiq

          def call(**)
            success(payload: {}, http_status: :ok)
          end
        end
      end

      it "rejects the historical Sidekiq label" do
        expect { workflow_class.call_from_job }.to raise_error(/use :delayed_continuation/)
      end
    end

    context "when :none returns deferred" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            deferred(reason: :provider_cooldown, retry_after: 5)
          end
        end
      end

      it "raises a programmer error" do
        expect { workflow_class.call_from_job }.to raise_error(
          CommandTower::Workflows::ApplicationWorkflow::InvalidDeferredResult
        )
      end
    end

    context "when :scheduled_cadence returns deferred" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :scheduled_cadence

          def call(**)
            deferred(reason: :lease_contention, retry_after: 5)
          end
        end
      end

      it "raises a programmer error" do
        expect { workflow_class.call_from_job }.to raise_error(
          CommandTower::Workflows::ApplicationWorkflow::InvalidDeferredResult
        )
      end
    end

    context "when :delayed_continuation is missing max_attempts" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :delayed_continuation

          def call(**)
            success(payload: {}, http_status: :ok)
          end
        end
      end

      it "raises" do
        expect { workflow_class.call_from_job }.to raise_error(/requires max_attempts/)
      end
    end

    context "when :none declares max_attempts" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none, max_attempts: 2

          def call(**)
            success(payload: {}, http_status: :ok)
          end
        end
      end

      it "raises" do
        expect { workflow_class.call_from_job }.to raise_error(/cannot declare max_attempts/)
      end
    end
  end

  describe "delayed continuation" do
    include ActiveJob::TestHelper

    let(:workflow_class) do
      Class.new(described_class) do
        retry_strategy :delayed_continuation, max_attempts: 2

        def call(token:)
          deferred(reason: :provider_cooldown, retry_after: 17, payload: { token: token })
        end
      end
    end

    let(:job_class) do
      Class.new(CommandTower::ApplicationJob) do
        def perform(token:, continuation_attempt: 1)
          # probe job — continuation is scheduled by call_from_job
        end
      end
    end

    before do
      stub_const("CommandTower::ContinuationProbeJob", job_class)
    end

    let(:job) { CommandTower::ContinuationProbeJob.new }

    context "when the first attempt is deferred" do
      subject(:result) { workflow_class.call_from_job(job: job, continuation_attempt: 1, token: "abc") }

      it "returns deferred metadata" do
        expect(result).to be_deferred
        expect(result.reason).to eq(:provider_cooldown)
        expect(result.retry_after).to eq(17)
      end

      it "schedules the same job arguments with wait and incremented attempt" do
        result
        expect(CommandTower::ContinuationProbeJob).to have_been_enqueued.with(
          token: "abc",
          continuation_attempt: 2
        ).at(be_within(1.second).of(17.seconds.from_now))
      end
    end

    it "requires a job instance to replay" do
      expect do
        workflow_class.call_from_job(continuation_attempt: 1, token: "abc")
      end.to raise_error(CommandTower::Workflows::ApplicationWorkflow::DelayedContinuationRequiresJob)
    end

    it "exhausts as a real job failure with no further enqueue" do
      expect do
        workflow_class.call_from_job(job: job, continuation_attempt: 2, token: "abc")
      end.to raise_error(CommandTower::Errors::ContinuationExhaustedError)
      expect(CommandTower::ContinuationProbeJob).not_to have_been_enqueued
    end

    context "when the workflow succeeds" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :delayed_continuation, max_attempts: 2

          def call(token:)
            success(payload: { token: token }, http_status: :ok)
          end
        end
      end

      it "returns success without enqueueing" do
        expect(workflow_class.call_from_job(job: job, continuation_attempt: 1, token: "abc")).to be_success
        expect(CommandTower::ContinuationProbeJob).not_to have_been_enqueued
      end
    end
  end

  describe "#transaction" do
    let(:app_error) do
      Class.new(CommandTower::Errors::ApplicationError) do
        def code
          "spec_transaction_error"
        end
      end.new
    end

    context "when the transaction succeeds" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(user:)
            transaction do
              user.update!(first_name: "Committed")
              success(payload: { user_id: user.id, first_name: user.first_name }, http_status: :ok)
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }
      subject(:result) { workflow_class.call(user: user) }

      it "commits a successful WorkflowResult and returns it" do
        expect(result).to be_success
        expect(result.payload[:first_name]).to eq("Committed")
        expect(user.reload.first_name).to eq("Committed")
      end
    end

    context "when fail_transaction! is used" do
      let(:captured_error) { app_error }
      let(:workflow_class) do
        error = captured_error
        Class.new(described_class) do
          retry_strategy :none

          define_method(:call) do |user:|
            transaction do
              user.update!(first_name: "ShouldRollback")
              fail_transaction!(
                failure(errors: [error], http_status: :unprocessable_entity)
              )
              success(payload: { unreachable: true }, http_status: :ok)
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }
      subject(:result) { workflow_class.call(user: user) }

      it "rolls back and returns the exact failure when fail_transaction! is used" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(captured_error)
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(user.reload.first_name).to eq("Before")
        expect(result.errors.first).not_to be_a(CommandTower::Errors::InternalError)
      end
    end

    context "when fail_transaction! follows multiple mutations" do
      let(:captured_error) { app_error }
      let(:workflow_class) do
        error = captured_error
        Class.new(described_class) do
          retry_strategy :none

          define_method(:call) do |user_a:, user_b:|
            transaction do
              user_a.update!(first_name: "AChanged")
              user_b.update!(first_name: "BChanged")
              fail_transaction!(
                failure(errors: [error], http_status: :unprocessable_entity)
              )
            end
          end
        end
      end

      let(:user_a) { create(:user, first_name: "A") }
      let(:user_b) { create(:user, first_name: "B") }
      subject(:result) { workflow_class.call(user_a: user_a, user_b: user_b) }

      it "rolls back all writes when fail_transaction! follows multiple mutations" do
        expect(result).to be_failure
        expect(user_a.reload.first_name).to eq("A")
        expect(user_b.reload.first_name).to eq("B")
      end
    end

    context "when an unexpected exception is raised inside the transaction" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(user:)
            transaction do
              user.update!(first_name: "ShouldRollback")
              raise StandardError, "unexpected boom"
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }

      before do
        allow(Rails.logger).to receive(:error)
      end

      subject(:result) { workflow_class.call(user: user) }

      it "rolls back and maps unexpected exceptions through existing .call handling" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::InternalError)
        expect(result.errors.first.cause.message).to eq("unexpected boom")
        expect(user.reload.first_name).to eq("Before")
      end
    end

    context "when a failed WorkflowResult is returned without fail_transaction!" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(user:)
            transaction do
              user.update!(first_name: "ShouldRollback")
              failure(
                errors: [CommandTower::Errors::ValidationError.new],
                http_status: :unprocessable_entity
              )
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }

      it "rejects a failed WorkflowResult returned without fail_transaction!" do
        expect { workflow_class.call(user: user) }.to raise_error(
          CommandTower::Workflows::ApplicationWorkflow::InvalidTransactionResult,
          /fail_transaction!/
        )
        expect(user.reload.first_name).to eq("Before")
      end
    end

    context "when work is performed before the transaction block" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(outside_user:, inside_user:)
            outside_user.update!(first_name: "OutsideCommitted")
            transaction do
              inside_user.update!(first_name: "InsideShouldRollback")
              fail_transaction!(
                failure(
                  errors: [CommandTower::Errors::ValidationError.new],
                  http_status: :unprocessable_entity
                )
              )
            end
          end
        end
      end

      let(:outside_user) { create(:user, first_name: "OutsideBefore") }
      let(:inside_user) { create(:user, first_name: "InsideBefore") }

      it "does not enclose work performed before the transaction block" do
        expect(workflow_class.call(outside_user: outside_user, inside_user: inside_user)).to be_failure
        expect(outside_user.reload.first_name).to eq("OutsideCommitted")
        expect(inside_user.reload.first_name).to eq("InsideBefore")
      end
    end
  end
end
