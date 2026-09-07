# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ExperienceStates::CompleteWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: user,
        experience_key:,
        scope_type:,
        scope_identifier:,
        version:,
        auth_context:,
      )
    end

    let(:user) { create(:user, roles: ["member"]) }
    let(:experience_key) { "welcome" }
    let(:scope_type) { "example_scope" }
    let(:scope_identifier) { "42" }
    let(:version) { "v1" }
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
      end
    end

    context "when completing for the first time" do
      it "returns the fact payload" do
        expect(result).to be_success
        expect(result.payload).to include(
          hostKey: "command_tower",
          experienceKey: "welcome",
          scopeType: "example_scope",
          scopeIdentifier: "42",
          version: "v1",
        )
        expect(result.payload.to_json).not_to include("showWelcome")
      end

      it "emits experience_state_completed once" do
        expect { result }.to change {
          CommandTower::Audit::Event.where(action: "experience_state_completed").count
        }.by(1)
      end

      context "when inspecting the audit row" do
        before { result }

        let(:row) { CommandTower::Audit::Event.find_by!(action: "experience_state_completed") }

        it "stores opaque host_context from the completion identity" do
          expect(row.affected_user_id).to eq(user.id)
          expect(row.scope_class).to eq("host")
          expect(row.host_context_type).to eq("example_scope")
          expect(row.host_context_identifier).to eq("42")
        end
      end
    end

    context "when replaying an existing completion" do
      let!(:existing) do
        create(
          :user_experience_state,
          user:,
          host_key: "command_tower",
          experience_key:,
          scope_type:,
          scope_identifier:,
          version:,
          completed_at: 3.days.ago.change(usec: 0),
        )
      end

      it "returns the existing completed_at" do
        expect(result).to be_success
        expect(Time.iso8601(result.payload[:completedAt])).to eq(existing.completed_at)
      end

      it "does not emit another audit event" do
        expect { result }.not_to change {
          CommandTower::Audit::Event.where(action: "experience_state_completed").count
        }
      end
    end
  end
end
