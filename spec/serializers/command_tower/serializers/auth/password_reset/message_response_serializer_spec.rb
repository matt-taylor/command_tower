# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::PasswordReset::MessageResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(message: "Password has been successfully reset") }

    it { is_expected.to eq(message: "Password has been successfully reset") }
  end
end
