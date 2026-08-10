# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::LogoutWorkflow do
  describe ".call" do
    subject(:result) { described_class.call }

    it "returns logged_out with clear_token" do
      expect(result).to be_success
      expect(result.http_status).to eq(:ok)
      expect(result.payload).to eq(message: "logged_out")
      expect(result.response_effects).to eq(clear_token: true)
    end
  end
end
