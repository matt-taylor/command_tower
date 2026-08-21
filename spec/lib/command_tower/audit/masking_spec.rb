# frozen_string_literal: true

RSpec.describe CommandTower::Audit::Masking do
  describe ".value" do
    it "returns nil for nil" do
      expect(described_class.value(field: "phone", raw: nil)).to be_nil
    end

    it "masks a phone to last four digits" do
      expect(described_class.value(field: "phone", raw: "+14155551212")).to eq("*******1212")
    end

    it "fully redacts a short phone" do
      expect(described_class.value(field: "phone", raw: "123")).to eq(described_class::REDACTED)
    end

    it "fully redacts a malformed phone" do
      expect(described_class.value(field: "phone", raw: "not-a-phone")).to eq(described_class::REDACTED)
    end

    it "masks an email without leaking the local-part" do
      expect(described_class.value(field: "email", raw: "matt@example.com")).to eq("m***@example.com")
    end

    it "fully redacts a malformed email" do
      expect(described_class.value(field: "email", raw: "not-an-email")).to eq(described_class::REDACTED)
    end

    it "fully redacts an unknown string field" do
      expect(described_class.value(field: "ssn", raw: "123-45-6789")).to eq(described_class::REDACTED)
    end

    it "fully redacts a non-scalar value" do
      expect(described_class.value(field: "phone", raw: { nested: true })).to eq(described_class::REDACTED)
    end
  end
end
