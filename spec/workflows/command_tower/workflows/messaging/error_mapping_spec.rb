# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Messaging::ErrorMapping do
  describe ".http_status_for" do
    subject(:status) { described_class.http_status_for(error) }

    context "when the error is ValidationError" do
      let(:error) { CommandTower::Errors::ValidationError.new }

      it { is_expected.to eq(:unprocessable_entity) }
    end

    context "when the error is RecipientUnresolvedError" do
      let(:error) { CommandTower::Errors::Messaging::RecipientUnresolvedError.new }

      it { is_expected.to eq(:unprocessable_entity) }
    end

    context "when the error is AcceptRejectedError" do
      let(:error) { CommandTower::Errors::Messaging::AcceptRejectedError.new }

      it { is_expected.to eq(:unprocessable_entity) }
    end

    context "when the error is IdempotencyConflictError" do
      let(:error) { CommandTower::Errors::Messaging::IdempotencyConflictError.new }

      it { is_expected.to eq(:conflict) }
    end

    context "when the error is NotFoundError" do
      let(:error) { CommandTower::Errors::NotFoundError.new }

      it { is_expected.to eq(:not_found) }
    end

    context "when the error is InternalError" do
      let(:error) { CommandTower::Errors::InternalError.new }

      it { is_expected.to eq(:internal_server_error) }
    end
  end
end
