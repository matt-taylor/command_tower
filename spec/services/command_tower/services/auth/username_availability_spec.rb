# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::UsernameAvailability do
  describe ".call" do
    subject(:result) { described_class.call(username: username) }

    context "with an available username" do
      let(:username) { "svcavailableuser" }

      it "returns valid and available" do
        expect(result).to be_success
        expect(result.data).to include(valid: true, available: true, message: "Username is available")
      end
    end

    context "with a taken username" do
      let!(:user) { create(:user, username: "svctakenuser") }
      let(:username) { "svctakenuser" }

      it "returns valid but unavailable" do
        expect(result).to be_success
        expect(result.data).to include(
          valid: true,
          available: false,
          message: "Username is already taken"
        )
      end
    end

    context "with an invalid username format" do
      let(:username) { "ab" }

      it "reports the configured failure message" do
        expect(result).to be_success
        expect(result.data[:valid]).to be(false)
        expect(result.data[:message]).to eq(CommandTower.config.username.username_failure_message)
      end
    end

    context "without a username" do
      let(:username) { nil }

      it "fails argument validation" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end
