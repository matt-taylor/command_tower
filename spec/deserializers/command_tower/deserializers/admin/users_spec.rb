# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Admin::Users::ListDeserializer do
  describe ".call" do
    context "when params are valid" do
      subject(:result) { described_class.call(limit: "10", offset: "5", search: " ada ") }

      it { expect(result).to be_success }

      it "coerces pagination and trims search" do
        expect(result.input).to have_attributes(limit: 10, offset: 5, search: "ada")
      end
    end

    context "when limit is invalid" do
      subject(:result) { described_class.call(limit: "0") }

      it { expect(result).to be_failure }
    end
  end
end

RSpec.describe CommandTower::Deserializers::Admin::Users::ShowDeserializer do
  describe ".call" do
    context "when id is valid" do
      subject(:result) { described_class.call(id: "42") }

      it { expect(result).to be_success }

      it { expect(result.input.id).to eq(42) }
    end

    context "when id is invalid" do
      subject(:result) { described_class.call(id: "abc") }

      it { expect(result).to be_failure }
    end
  end
end

RSpec.describe CommandTower::Deserializers::Admin::Users::UpdateRolesDeserializer do
  describe ".call" do
    context "when roles is a valid array" do
      subject(:result) { described_class.call(id: "42", roles: %w[member support_admin]) }

      it { expect(result).to be_success }

      it { expect(result.input.roles).to eq(%w[member support_admin]) }
    end

    context "when roles is not an array" do
      subject(:result) { described_class.call(id: "42", roles: "member") }

      it { expect(result).to be_failure }
    end

    context "when id is invalid" do
      subject(:result) { described_class.call(id: "abc", roles: %w[member]) }

      it { expect(result).to be_failure }
    end
  end
end
