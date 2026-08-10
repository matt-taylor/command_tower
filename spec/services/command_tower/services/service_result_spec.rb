# frozen_string_literal: true

RSpec.describe CommandTower::Services::ServiceResult do
  describe ".from_interactor_context" do
    subject(:result) { described_class.from_interactor_context(context) }

    context "when successful" do
      let(:context) do
        Interactor::Context.new(value: "ok", service_metadata: { trace: 1 }).tap do |ctx|
          allow(ctx).to receive(:success?).and_return(true)
        end
      end

      it "returns success with data and metadata" do
        expect(result).to be_success
        expect(result.data).to include(value: "ok")
        expect(result.metadata).to eq(trace: 1)
      end
    end

    context "when application_error is present" do
      let(:application_error) { CommandTower::Errors::UnauthorizedError.new }
      let(:context) do
        Interactor::Context.new(application_error: application_error).tap do |ctx|
          allow(ctx).to receive(:success?).and_return(false)
        end
      end

      it "returns that application error" do
        expect(result).to be_failure
        expect(result.errors).to eq([application_error])
      end
    end

    context "when invalid_arguments is present" do
      let(:context) do
        Interactor::Context.new(
          application_error: nil,
          invalid_arguments: true,
          invalid_argument_hash: { email: "bad" }
        ).tap do |ctx|
          allow(ctx).to receive(:success?).and_return(false)
        end
      end

      it "maps to ValidationError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to eq(email: "bad")
      end
    end

    context "when failed without application_error or invalid_arguments" do
      let(:context) do
        Interactor::Context.new(
          msg: "nope",
          application_error: nil,
          invalid_arguments: nil
        ).tap do |ctx|
          allow(ctx).to receive(:success?).and_return(false)
        end
      end

      it "maps to InternalError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::InternalError)
      end
    end
  end
end
