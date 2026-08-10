# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Application::EnvelopeSerializer do
  describe ".success" do
    subject(:body) { described_class.success(data: { id: 1 }, meta: { page: 1 }) }

    it "builds the success envelope" do
      expect(body).to eq(data: { id: 1 }, meta: { page: 1 }, errors: [])
    end
  end

  describe ".failure" do
    subject(:body) { described_class.failure(errors: [{ code: "x", message: "y" }]) }

    it "builds the failure envelope" do
      expect(body).to eq(data: nil, meta: {}, errors: [{ code: "x", message: "y" }])
    end
  end
end
