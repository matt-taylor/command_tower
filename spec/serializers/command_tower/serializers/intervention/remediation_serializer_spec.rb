# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Intervention::RemediationSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(kind: kind, action: action, label: label) }

    let(:kind) { "navigate" }
    let(:action) { "contact_commissioner" }
    let(:label) { "Contact commissioner" }

    it "builds the remediation shape" do
      expect(payload).to eq(
        kind: "navigate",
        action: "contact_commissioner",
        label: "Contact commissioner"
      )
    end

    context "when label is omitted" do
      subject(:payload) { described_class.serialize(kind: kind, action: action) }

      it "omits label" do
        expect(payload).to eq(kind: "navigate", action: "contact_commissioner")
      end
    end
  end
end
