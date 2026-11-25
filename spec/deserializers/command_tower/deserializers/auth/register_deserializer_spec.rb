# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Auth::RegisterDeserializer do
  describe "#call" do
    subject(:result) { described_class.call(params) }

    context "with the old six-field shape" do
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
        expect(result.input.start_session).to be(false)
      end
    end

    context "with the new shape (email and password only)" do
      let(:params) { { email: "Ada@Example.com", password: "secret123", start_session: true } }

      it "leaves the optional fields empty and reads start_session" do
        expect(result).to be_success
        expect(result.input.first_name).to eq("")
        expect(result.input.last_name).to eq("")
        expect(result.input.username).to be_nil
        expect(result.input.password_confirmation).to be_nil
        expect(result.input.start_session).to be(true)
      end
    end

    context "with start_session as a string" do
      let(:params) { { email: "ada@example.com", password: "secret123", start_session: "false" } }

      it { expect(result.input.start_session).to be(false) }
    end

    %i[email password].each do |missing_field|
      context "when #{missing_field} is missing" do
        let(:params) { { email: "ada@example.com", password: "secret123" }.except(missing_field) }

        it { is_expected.to be_failure }
      end
    end
  end
end
