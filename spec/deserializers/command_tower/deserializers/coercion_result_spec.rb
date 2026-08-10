# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::CoercionResult do
  describe ".ok" do
    subject(:result) { described_class.ok(12) }

    it { expect(result).to be_ok }
    it { expect(result).not_to be_failure }
    it { expect(result.value).to eq(12) }
    it { expect(result.failures).to eq([]) }
  end

  describe ".fail" do
    subject(:result) { described_class.fail(code: "invalid_limit", field: "limit") }

    it { expect(result).to be_failure }
    it { expect(result.value).to be_nil }

    it "includes a normalized failure entry" do
      expect(result.failures).to contain_exactly(
        hash_including(code: "invalid_limit", field: "limit")
      )
    end
  end
end
