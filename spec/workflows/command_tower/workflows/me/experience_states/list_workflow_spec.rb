# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ExperienceStates::ListWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(current_user: user, auth_context:)
    end

    let(:user) { create(:user, roles: ["member"]) }
    let(:auth_context) do
      CommandTower::Auth::AuthContext.new(
        user:,
        token_expires_at: 1.hour.from_now.iso8601,
        token_source: :header,
        roles: user.roles,
        principal_type: :user,
        generated_token: nil,
      )
    end

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

      it "maps to service unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStatesHostUnconfiguredError)
      end
    end

    context "when completions exist" do
      before do
        create(:user_experience_state, user:, host_key: "command_tower", scope_identifier: "1")
        create(:user_experience_state, user:, host_key: "other_host", scope_identifier: "2")
      end

      it "returns fact-only payload for the configured host" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:experienceStates].size).to eq(1)
        expect(result.payload[:experienceStates].first).to include(
          hostKey: "command_tower",
          experienceKey: "welcome",
          scopeIdentifier: "1",
        )
        expect(result.payload.to_json).not_to include("showWelcome")
        expect(result.response_effects[:set_expire_header]).to be_present
      end
    end
  end
end
