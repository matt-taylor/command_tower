# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Admin::Users::UpdateNameDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with camelCase fields" do
      let(:params) { { id: "42", firstName: "Ada", lastName: "Lovelace" } }

      it { expect(result).to be_success }

      it "coerces id and names" do
        expect(result.input).to have_attributes(id: 42, first_name: "Ada", last_name: "Lovelace")
      end
    end

    context "with blank names" do
      let(:params) { { id: "42", firstName: "", lastName: "Lovelace" } }

      it { expect(result).to be_failure }
    end
  end
end

RSpec.describe CommandTower::Deserializers::Admin::Users::UpdateEmailValidationDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with camelCase boolean" do
      let(:params) { { id: "7", emailValidated: false } }

      it { expect(result).to be_success }

      it { expect(result.input.email_validated).to eq(false) }
    end

    context "with snake_case boolean" do
      let(:params) { { id: "7", email_validated: true } }

      it { expect(result).to be_success }

      it { expect(result.input.email_validated).to eq(true) }
    end

    context "when the boolean is missing" do
      let(:params) { { id: "7" } }

      it { expect(result).to be_failure }
    end
  end
end
