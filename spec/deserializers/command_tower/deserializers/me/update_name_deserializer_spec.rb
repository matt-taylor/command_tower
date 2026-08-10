# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Me::UpdateNameDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with camelCase fields" do
      let(:params) { { firstName: "Ada", lastName: "Lovelace" } }

      it "succeeds" do
        expect(result).to be_success
        expect(result.input.first_name).to eq("Ada")
        expect(result.input.last_name).to eq("Lovelace")
      end
    end

    context "with blank fields" do
      let(:params) { { firstName: "", lastName: "Lovelace" } }

      it "fails" do
        expect(result).not_to be_success
      end
    end
  end
end
