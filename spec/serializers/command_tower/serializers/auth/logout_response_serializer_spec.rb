# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::LogoutResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize }

    it { expect(payload).to eq(message: "logged_out") }
  end
end
