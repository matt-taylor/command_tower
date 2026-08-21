# frozen_string_literal: true

RSpec.describe CommandTower::Services::ApplicationService do
  let(:successful_test_service) do
    Class.new(described_class) do
      def call
        context.value = "ok"
      end
    end
  end

  let(:failing_test_service) do
    Class.new(described_class) do
      def call
        context.fail!(application_error: CommandTower::Errors::UnauthorizedError.new)
      end
    end
  end

  let(:validation_failing_test_service) do
    Class.new(described_class) do
      validate :email, required: true

      def call
      end
    end
  end

  let(:exploding_test_service) do
    Class.new(described_class) do
      def call
        raise "boom"
      end
    end
  end

  it "inherits from CommandTower::ServiceBase" do
    expect(described_class.superclass).to eq(CommandTower::ServiceBase)
  end

  it "defaults to fail_early argument validation" do
    expect(described_class.on_argument_validation_assigned).to eq(:fail_early)
  end

  describe ".call" do
    context "on success" do
      subject(:result) { successful_test_service.call }

      it "returns a ServiceResult on success" do
        expect(result).to be_a(CommandTower::Services::ServiceResult)
        expect(result).to be_success
        expect(result.data).to eq(value: "ok")
      end
    end

    context "on known failure" do
      subject(:result) { failing_test_service.call }

      it "returns a ServiceResult on known failure" do
        expect(result).to be_a(CommandTower::Services::ServiceResult)
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::UnauthorizedError)
      end
    end

    context "on argument validation failure" do
      subject(:result) { validation_failing_test_service.call }

      it "maps argument validation failures to ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "on unexpected exception" do
      subject(:invoke) { exploding_test_service.call }

      it "does not swallow unexpected exceptions" do
        expect { invoke }.to raise_error(RuntimeError, "boom")
      end
    end
  end

  describe "#transaction" do
    let(:app_error) do
      Class.new(CommandTower::Errors::ApplicationError) do
        def code
          "spec_service_transaction_error"
        end
      end.new
    end

    context "when the transaction succeeds" do
      let(:service_class) do
        Class.new(described_class) do
          validate :user, required: true

          def call
            transaction do
              user.update!(first_name: "Committed")
              context.first_name = user.first_name
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }
      subject(:result) { service_class.call(user: user) }

      it "commits mutations and returns a successful ServiceResult" do
        expect(result).to be_success
        expect(result.data[:first_name]).to eq("Committed")
        expect(user.reload.first_name).to eq("Committed")
      end
    end

    context "when fail_transaction! is used with a failed ServiceResult" do
      let(:captured_error) { app_error }
      let(:service_class) do
        error = captured_error
        Class.new(described_class) do
          validate :user, required: true

          define_method(:call) do
            transaction do
              user.update!(first_name: "ShouldRollback")
              fail_transaction!(
                CommandTower::Services::ServiceResult.failure(errors: [error])
              )
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }
      subject(:result) { service_class.call(user: user) }

      it "rolls back and returns the exact application error" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(captured_error)
        expect(user.reload.first_name).to eq("Before")
        expect(result.errors.first).not_to be_a(CommandTower::Errors::InternalError)
      end
    end

    context "when fail_transaction! follows multiple mutations" do
      let(:captured_error) { app_error }
      let(:service_class) do
        error = captured_error
        Class.new(described_class) do
          validate :user_a, required: true
          validate :user_b, required: true

          define_method(:call) do
            transaction do
              user_a.update!(first_name: "AChanged")
              user_b.update!(first_name: "BChanged")
              fail_transaction!(error)
            end
          end
        end
      end

      let(:user_a) { create(:user, first_name: "A") }
      let(:user_b) { create(:user, first_name: "B") }
      subject(:result) { service_class.call(user_a: user_a, user_b: user_b) }

      it "rolls back all writes" do
        expect(result).to be_failure
        expect(user_a.reload.first_name).to eq("A")
        expect(user_b.reload.first_name).to eq("B")
      end
    end

    context "when a failed ServiceResult is returned without fail_transaction!" do
      let(:service_class) do
        Class.new(described_class) do
          validate :user, required: true

          def call
            transaction do
              user.update!(first_name: "ShouldRollback")
              CommandTower::Services::ServiceResult.failure(
                errors: [CommandTower::Errors::ValidationError.new]
              )
            end
          end
        end
      end

      let(:user) { create(:user, first_name: "Before") }
      subject(:invoke) { service_class.call(user: user) }

      it "rejects a failed ServiceResult returned without fail_transaction!" do
        expect { invoke }.to raise_error(
          CommandTower::Transactional::InvalidTransactionResult,
          /fail_transaction!/
        )
        expect(user.reload.first_name).to eq("Before")
      end
    end

    context "when work is performed before the transaction block" do
      let(:service_class) do
        Class.new(described_class) do
          validate :outside_user, required: true
          validate :inside_user, required: true

          def call
            outside_user.update!(first_name: "OutsideCommitted")
            transaction do
              inside_user.update!(first_name: "InsideShouldRollback")
              fail_transaction!(CommandTower::Errors::ValidationError.new)
            end
          end
        end
      end

      let(:outside_user) { create(:user, first_name: "OutsideBefore") }
      let(:inside_user) { create(:user, first_name: "InsideBefore") }

      it "does not enclose work performed before the transaction block" do
        expect(service_class.call(outside_user: outside_user, inside_user: inside_user)).to be_failure
        expect(outside_user.reload.first_name).to eq("OutsideCommitted")
        expect(inside_user.reload.first_name).to eq("InsideBefore")
      end
    end
  end
end
