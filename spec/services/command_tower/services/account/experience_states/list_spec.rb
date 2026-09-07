# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::ExperienceStates::List do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }

    around do |example|
      previous = CommandTower.config.application.host_key
      CommandTower.config.application.host_key = host_key
      example.run
    ensure
      CommandTower.config.application.host_key = previous
    end

    let(:host_key) { "command_tower" }

    context "when host_key is blank" do
      let(:host_key) { "" }

      it "fails as unconfigured" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStatesHostUnconfiguredError)
      end
    end

    context "when rows exist for multiple hosts and scopes" do
      let!(:matching) do
        create(:user_experience_state, user:, host_key: "command_tower", scope_identifier: "1")
      end
      let!(:other_host) do
        create(:user_experience_state, user:, host_key: "other_host", scope_identifier: "1")
      end
      let!(:other_user) do
        create(:user_experience_state, host_key: "command_tower", scope_identifier: "1")
      end

      it "returns only the current user and configured host rows" do
        expect(result).to be_success
        expect(result.data[:experience_states]).to contain_exactly(matching)
        expect(result.data[:experience_states]).not_to include(other_host, other_user)
      end
    end

    context "when no rows exist" do
      it "returns an empty collection" do
        expect(result).to be_success
        expect(result.data[:experience_states]).to eq([])
      end
    end
  end
end
