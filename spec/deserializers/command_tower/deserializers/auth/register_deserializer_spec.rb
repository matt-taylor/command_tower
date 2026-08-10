# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::RegisterDeserializer do
  describe "#call" do
    subject(:result) { described_class.call(params) }

    context "when all required fields are present" do
      let(:params) do
        {
          first_name: "  Ada  ",
          last_name: "  Lovelace  ",
          username: "  adalove  ",
          email: "  ADA@Example.com  ",
          password: "secret123",
          password_confirmation: "secret123"
        }
      end

      it "returns success input with normalized fields" do
        expect(result).to be_success
        expect(result.input.first_name).to eq("Ada")
        expect(result.input.last_name).to eq("Lovelace")
        expect(result.input.username).to eq("adalove")
        expect(result.input.email).to eq("ada@example.com")
        expect(result.input.password).to eq("secret123")
        expect(result.input.password_confirmation).to eq("secret123")
      end
    end

    %i[first_name last_name username email password password_confirmation].each do |missing_field|
      context "when #{missing_field} is missing" do
        let(:params) do
          {
            first_name: "Ada",
            last_name: "Lovelace",
            username: "adalove",
            email: "ada@example.com",
            password: "secret123",
            password_confirmation: "secret123"
          }.except(missing_field)
        end

        it { is_expected.to be_failure }
      end
    end
  end
end
