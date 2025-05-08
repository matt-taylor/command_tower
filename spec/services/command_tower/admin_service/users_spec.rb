# frozen_string_literal: true

RSpec.describe CommandTower::AdminService::Users do
  describe ".call" do
    subject(:call) { described_class.(user:, pagination:) }

    let(:pagination) { nil }
    let(:user) { create(:user) }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets metadata" do
      expect(call.schema).to be_a(CommandTower::Schema::Admin::Users)
      expect(call.schema.count).to eq(1)
      expect(call.schema.users.length).to eq(1)
    end

    context "with include_examples" do
      let!(:records) { create_list(:user, count) }
      let(:records_chain) { [:schema, :users] }
      let(:records_count) { [:schema, :count] }

      include_examples "Services Pagination examples", ::User
    end
  end
end
