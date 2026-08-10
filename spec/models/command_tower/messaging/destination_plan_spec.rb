# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::DestinationPlan, type: :model do
  subject(:destination_plan) { create(:messaging_destination_plan, communication:) }

  let(:communication) { create(:messaging_communication) }

  describe "associations" do
    it "belongs to a communication" do
      expect(destination_plan.communication).to eq(communication)
    end
  end

  describe "validations" do
    it "allows one plan per communication" do
      expect(destination_plan).to be_persisted
    end

    context "with a duplicate plan for the same communication" do
      let(:duplicate) { build(:messaging_destination_plan, communication:) }

      before { destination_plan }

      it "rejects the duplicate at validation" do
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:communication_id]).to be_present
      end
    end

    it "enforces uniqueness at the database" do
      destination_plan
      expect do
        described_class.insert!({
          communication_id: communication.id,
          created_at: Time.current,
          updated_at: Time.current,
        })
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
