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
end
