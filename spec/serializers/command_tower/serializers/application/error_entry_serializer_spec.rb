# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Application::ErrorEntrySerializer do
  describe ".serialize" do
    context "without details" do
      subject(:entry) { described_class.serialize(CommandTower::Errors::UnauthorizedError.new) }

      it { expect(entry).to eq(code: "unauthorized", message: "Unauthorized") }
    end

    context "with details" do
      subject(:entry) do
        described_class.serialize(
          CommandTower::Errors::ValidationError.new(details: { email: "bad" })
        )
      end

      it "includes details" do
        expect(entry).to eq(
          code: "validation_failed",
          message: "Validation failed",
          details: { email: "bad" }
        )
      end
    end
  end
end
