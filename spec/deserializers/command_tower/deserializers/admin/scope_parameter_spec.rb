# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Admin::ScopeParameter do
  describe ".extract" do
    context "when the tool does not require scope" do
      subject(:result) { described_class.extract({ partition: "scope-a" }, tool_id: "messaging") }

      it { expect(result).to be_nil }
    end

    context "when the tool requires scope" do
      before { register_foundation_proof_scoped_admin! }

      context "when the snake_case param is present" do
        subject(:result) { described_class.extract({ partition: " scope-a " }, tool_id: "users") }

        it { expect(result).to eq("scope-a") }
      end

      context "when the camelCase param is present" do
        subject(:result) { described_class.extract({ partition: "scope-b" }, tool_id: "users") }

        it { expect(result).to eq("scope-b") }
      end

      context "when the param is absent" do
        subject(:result) { described_class.extract({}, tool_id: "users") }

        it { expect(result).to be_nil }
      end
    end
  end
end
