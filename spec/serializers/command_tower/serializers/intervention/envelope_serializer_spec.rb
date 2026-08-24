# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Intervention::EnvelopeSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(action: action, allowed: allowed, blockers: blockers) }

    let(:action) { "wager.place" }
    let(:allowed) { false }
    let(:blockers) do
      [
        {
          code: "dues_unpaid",
          action: "wager.place",
          title: "Dues unpaid",
          message: "Pay league dues to place picks.",
          remediation: { kind: "navigate", action: "contact_commissioner" }
        }
      ]
    end

    it "builds the action-scoped envelope" do
      expect(payload).to eq(
        action: "wager.place",
        allowed: false,
        blockers: [
          {
            code: "dues_unpaid",
            action: "wager.place",
            title: "Dues unpaid",
            message: "Pay league dues to place picks.",
            remediation: {
              kind: "navigate",
              action: "contact_commissioner"
            }
          }
        ]
      )
    end

    context "when allowed with no blockers" do
      let(:allowed) { true }
      let(:blockers) { [] }

      it "returns an empty blockers list" do
        expect(payload).to eq(action: "wager.place", allowed: true, blockers: [])
      end
    end
  end

  describe ".serialize_many" do
    subject(:payload) { described_class.serialize_many(envelopes) }

    let(:envelopes) do
      [
        { action: "wager.place", allowed: true, blockers: [] },
        { action: "wager.update", allowed: true, blockers: [] }
      ]
    end

    it "serializes each envelope" do
      expect(payload).to eq(
        [
          { action: "wager.place", allowed: true, blockers: [] },
          { action: "wager.update", allowed: true, blockers: [] }
        ]
      )
    end
  end
end
