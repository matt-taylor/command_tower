# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Intervention::BlockerSerializer do
  describe ".serialize" do
    subject(:payload) do
      described_class.serialize(
        code: code,
        action: action,
        title: title,
        message: message,
        remediation: remediation,
        severity: severity
      )
    end

    let(:code) { "dues_unpaid" }
    let(:action) { "wager.place" }
    let(:title) { "Dues unpaid" }
    let(:message) { "Pay league dues to place picks." }
    let(:remediation) { { kind: "navigate", action: "contact_commissioner", label: "Contact commissioner" } }
    let(:severity) { "blocking" }

    it "builds the blocker shape" do
      expect(payload).to eq(
        code: "dues_unpaid",
        action: "wager.place",
        title: "Dues unpaid",
        message: "Pay league dues to place picks.",
        severity: "blocking",
        remediation: {
          kind: "navigate",
          action: "contact_commissioner",
          label: "Contact commissioner"
        }
      )
    end

    context "without optional fields" do
      subject(:payload) do
        described_class.serialize(
          code: code,
          action: action,
          title: title,
          message: message
        )
      end

      it "omits severity and remediation" do
        expect(payload).to eq(
          code: "dues_unpaid",
          action: "wager.place",
          title: "Dues unpaid",
          message: "Pay league dues to place picks."
        )
      end
    end
  end
end
