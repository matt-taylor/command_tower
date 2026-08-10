# frozen_string_literal: true

RSpec.describe CommandTower::Clients::EndpointInput do
  let(:fake_input_class) do
    Class.new(described_class) do
      attribute :value
    end
  end

  describe "#==" do
    let(:left) { fake_input_class.new(value: 1) }
    let(:right) { fake_input_class.new(value: 1) }
    let(:other) { fake_input_class.new(value: 2) }

    it "compares by attributes using instance_of?" do
      expect(left).to eq(right)
      expect(left).not_to eq(other)
    end
  end

  describe "untyped attributes" do
    subject(:input) { fake_input_class.new(value: "2") }

    it "does not coerce string assignment through typed ActiveModel casts" do
      expect(input.value).to eq("2")
      expect(input.value).to be_a(String)
    end
  end
end
