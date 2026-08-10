# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Me::UpdatePhoneDeserializer do
  context "with phoneNumber" do
    subject(:result) { described_class.call(phoneNumber: "4155552671") }

    it { expect(result).to be_success }
    it { expect(result.input.phone_number).to eq("4155552671") }
  end

  it "rejects blank phone" do
    expect(described_class.call(phoneNumber: "  ")).to be_failure
  end
end
