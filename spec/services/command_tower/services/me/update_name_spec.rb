# frozen_string_literal: true

RSpec.describe CommandTower::Services::Me::UpdateName do
  describe ".call" do
    subject(:result) do
      described_class.call(user:, first_name:, last_name:)
    end

    let(:user) { create(:user, first_name: "Old", last_name: "Name") }
    let(:first_name) { "New" }
    let(:last_name) { "Person" }

    it "updates both name fields" do
      expect(result).to be_success
      expect(user.reload).to have_attributes(first_name: "New", last_name: "Person")
    end

    context "when names are unchanged" do
      let(:first_name) { "Old" }
      let(:last_name) { "Name" }

      it "succeeds without modifying the user" do
        expect { result }.not_to(change { user.reload.updated_at })
        expect(result).to be_success
      end
    end
  end
end
