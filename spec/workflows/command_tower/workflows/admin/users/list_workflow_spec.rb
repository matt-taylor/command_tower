# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Users::ListWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(limit: 50, offset: 0, search: nil, user:) }

    let(:user) { create(:user) }
    let!(:listed_user) { create(:user) }

    it { expect(result).to be_success }

    it "serializes users into the workflow payload" do
      expect(result.payload.map { |row| row.fetch(:id) }).to include(listed_user.id)
      expect(result.meta).to include(:limit, :offset, :totalCount)
    end
  end
end
