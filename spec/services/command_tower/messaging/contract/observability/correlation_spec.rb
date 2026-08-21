# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Observability::Correlation do
  after { CommandTower::Current.reset }

  describe ".resolve" do
    subject(:resolve) { described_class.resolve }

    context "when Current.correlation_id and Current.request_id are present" do
      before do
        CommandTower::Current.correlation_id = "corr-id"
        CommandTower::Current.request_id = "ambient-id"
      end

      it "prefers correlation_id" do
        expect(resolve).to eq("corr-id")
      end
    end

    context "when Current.request_id is present" do
      before { CommandTower::Current.request_id = "ambient-id" }

      it "returns the ambient request_id" do
        expect(resolve).to eq("ambient-id")
      end
    end

    context "when Current.request_id is blank" do
      before { CommandTower::Current.request_id = nil }

      it "returns a UUID" do
        expect(resolve).to match(
          /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
        )
      end
    end
  end
end
