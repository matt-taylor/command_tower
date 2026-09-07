# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Me::ExperienceStates::CompleteDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with camelCase params" do
      let(:params) do
        {
          experienceKey: "welcome",
          scopeType: "example_scope",
          scopeIdentifier: "42",
          version: "v1",
        }
      end

      it "returns the input" do
        expect(result).to be_success
        expect(result.input).to have_attributes(
          experience_key: "welcome",
          scope_type: "example_scope",
          scope_identifier: "42",
          version: "v1",
        )
      end
    end

    context "with snake_case params" do
      let(:params) do
        {
          experience_key: "welcome",
          scope_type: "example_scope",
          scope_identifier: "42",
          version: "v1",
        }
      end

      it "returns the input" do
        expect(result).to be_success
        expect(result.input.experience_key).to eq("welcome")
      end
    end

    context "when a required field is missing" do
      let(:params) { { experienceKey: "welcome", scopeType: "example_scope", version: "v1" } }

      it "fails" do
        expect(result).to be_failure
      end
    end

    context "when a field exceeds the length bound" do
      let(:params) do
        {
          experienceKey: "welcome",
          scopeType: "example_scope",
          scopeIdentifier: "x" * 129,
          version: "v1",
        }
      end

      it "fails" do
        expect(result).to be_failure
      end
    end

    context "when hostKey is supplied" do
      let(:params) do
        {
          experienceKey: "welcome",
          scopeType: "example_scope",
          scopeIdentifier: "42",
          version: "v1",
          hostKey: "attacker",
        }
      end

      it "ignores client hostKey" do
        expect(result).to be_success
        expect(result.input.to_h.keys).not_to include(:host_key, :hostKey)
      end
    end
  end
end
