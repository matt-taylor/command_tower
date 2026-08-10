# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::EmailVerification::MessageResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(message: "Successfully verified email") }

    it { is_expected.to eq(message: "Successfully verified email") }
  end
end
