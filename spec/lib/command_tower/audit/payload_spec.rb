# frozen_string_literal: true

RSpec.describe CommandTower::Audit::Payload do
  describe ".validate_changes!" do
    context "when changes are empty" do
      subject(:result) { described_class.validate_changes!({}, allowed_keys: []) }

      it { expect(result).to eq({}) }
    end

    context "when nested from/to values are valid" do
      subject(:result) do
        described_class.validate_changes!(
          { email: { from: "a@example.com", to: "b@example.com" } },
          allowed_keys: %i[email]
        )
      end

      it "preserves nested values" do
        expect(result).to eq("email" => { "from" => "a@example.com", "to" => "b@example.com" })
      end
    end

    context "when a change key is not allowed" do
      subject(:invoke) do
        described_class.validate_changes!(
          { email: { from: "a", to: "b" }, password_digest: { from: "x", to: "y" } },
          allowed_keys: %i[email]
        )
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::ForbiddenChangeKeyError, /password_digest/)
      end
    end

    context "when a change value is not a from/to hash" do
      subject(:invoke) do
        described_class.validate_changes!({ role: "member" }, allowed_keys: %i[role])
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidPayloadError, /from\/to/)
      end
    end

    context "when a value is an unsafe object" do
      subject(:invoke) do
        described_class.validate_changes!(
          { role: { from: nil, to: Object.new } },
          allowed_keys: %i[role]
        )
      end

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidPayloadError, /unsafe type/)
      end
    end
  end

  describe ".validate_metadata!" do
    context "when metadata is valid" do
      subject(:result) { described_class.validate_metadata!({ reason: "admin" }) }

      it { expect(result).to eq("reason" => "admin") }
    end

    context "when metadata contains an ActiveRecord object" do
      let(:user) { create(:user) }

      subject(:invoke) { described_class.validate_metadata!({ user: user }) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::InvalidPayloadError, /unsafe type/)
      end
    end
  end
end
