# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Transport::Response do
  describe ".build" do
    subject(:response) do
      described_class.build(
        status: "201",
        headers: { "Content-Type" => "application/json" },
        body: "{}",
        duration_ms: 12
      )
    end

    it "normalizes status and headers" do
      expect(response.status).to eq(201)
      expect(response.headers).to eq("Content-Type" => "application/json")
      expect(response.body).to eq("{}")
      expect(response.duration_ms).to eq(12)
    end
  end

  describe "#success?" do
    it "is true for 2xx" do
      expect(described_class.build(status: 204)).to be_success
    end

    it "is false for non-2xx" do
      expect(described_class.build(status: 404)).not_to be_success
    end
  end
end
