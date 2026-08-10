# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Recipients do
  describe ".call" do
    context "with a persisted user" do
      let(:user) { create(:user) }

      subject(:result) { described_class.call(user:) }

      it "resolves a persisted user id" do
        expect(result).to be_success
        expect(result.data[:recipient_id]).to eq(user.id)
      end
    end

    context "with an unpersisted user" do
      subject(:result) { described_class.call(user: build(:user)) }

      it "fails for an unpersisted user" do
        expect(result).not_to be_success
        expect(result.errors.first).to be_a(CommandTower::Errors::Messaging::RecipientUnresolvedError)
      end
    end
  end
end
