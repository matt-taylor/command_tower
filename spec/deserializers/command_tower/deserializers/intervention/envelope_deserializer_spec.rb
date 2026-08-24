# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Intervention::EnvelopeDeserializer do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    let(:params) do
      {
        "action" => "wager.place",
        "allowed" => false,
        "blockers" => [
          {
            "code" => "dues_unpaid",
            "action" => "wager.place",
            "title" => "Dues unpaid",
            "message" => "Pay league dues to place picks.",
            "remediation" => {
              "kind" => "navigate",
              "action" => "contact_commissioner",
              "label" => "Contact commissioner"
            }
          }
        ]
      }
    end

    it "parses a canonical envelope" do
      expect(result).to be_success
      expect(result.input.action).to eq("wager.place")
      expect(result.input.allowed).to eq(false)
      expect(result.input.blockers).to eq(
        [
          {
            code: "dues_unpaid",
            action: "wager.place",
            title: "Dues unpaid",
            message: "Pay league dues to place picks.",
            remediation: {
              kind: "navigate",
              action: "contact_commissioner",
              label: "Contact commissioner"
            }
          }
        ]
      )
    end

    context "when action is missing" do
      let(:params) { { "allowed" => true, "blockers" => [] } }

      it "fails" do
        expect(result).to be_failure
        expect(result.errors.first[:field]).to eq("action")
      end
    end

    context "when blockers is not an array" do
      let(:params) { { "action" => "wager.place", "allowed" => true, "blockers" => {} } }

      it "fails" do
        expect(result).to be_failure
        expect(result.errors.first[:field]).to eq("blockers")
      end
    end
  end
end
