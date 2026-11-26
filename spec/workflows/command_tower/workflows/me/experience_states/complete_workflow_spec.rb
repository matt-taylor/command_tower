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

        it "records experience_key and version as metadata, never the scope identifier" do
          expect(row.metadata).to eq("experience_key" => "welcome", "version" => "v1")
          expect(row.metadata.to_json).not_to include("42")
        end

        it "retains the event for one year" do
          expect(CommandTower.config.registry.audit.fetch(:experience_state_completed).retention).to eq(:one_year)
        end

        it "stores opaque host_context from the completion identity" do
          expect(row.affected_user_id).to eq(user.id)
          expect(row.scope_class).to eq("host")
          expect(row.host_context_type).to eq("example_scope")
          expect(row.host_context_identifier).to eq("42")
        end
      end
    end

    context "when impersonating" do
      before do
        allow(CommandTower::Current).to receive(:impersonation_active).and_return(true)
        allow(CommandTower::Services::Account::ExperienceStates::CheckCompleteRateLimit).to receive(:call)
      end

      it "fails forbidden before the rate limit is consulted", :aggregate_failures do
        expect(result.http_status).to eq(:forbidden)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStateImpersonationForbidden)
        expect(CommandTower::Services::Account::ExperienceStates::CheckCompleteRateLimit).not_to have_received(:call)
        expect(CommandTower::UserExperienceState.count).to eq(0)
      end
    end

    context "when rate limited" do
      before do
        allow(CommandTower.config.registry.experience_states).to receive(:complete_rate)
          .and_return({ limit: 1, window: 60 })
        flush_signup_rate_limits!
      end

      it "returns 429 on the second request" do
        described_class.call(current_user: user, experience_key:, scope_type:, scope_identifier:, version:)
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors.first.details[:retry_after_seconds]).to be_positive
      end

      context "with an unregistered key" do
        let(:experience_key) { "nope" }

        it "throttles unregistered traffic before the registry check", :aggregate_failures do
          described_class.call(current_user: user, experience_key:, scope_type:, scope_identifier:, version:)
          expect(result.http_status).to eq(:too_many_requests)
        end
      end
    end

    context "when the key or scope type is not registered" do
      let(:experience_key) { "nope" }

      it "fails 422 without echoing input", :aggregate_failures do
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStateUnregistered)
        expect(result.errors.first.message).not_to include("nope")
        expect(CommandTower::UserExperienceState.count).to eq(0)
      end

      context "with a registered key under an unlisted scope type" do
        let(:experience_key) { "welcome" }
        let(:scope_type) { "other_scope" }

        it "fails 422" do
          expect(result.http_status).to eq(:unprocessable_entity)
          expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStateUnregistered)
        end
      end
    end

    context "when the per-user cap is reached" do
      before do
        allow(CommandTower.config.registry.experience_states).to receive(:max_rows_per_user).and_return(1)
        create(:user_experience_state, user:, host_key: "command_tower", experience_key: "other",
                                       scope_type:, scope_identifier: "1", version:)
      end

      it "fails 422 for a new fact without auditing", :aggregate_failures do
        expect { result }.not_to change(CommandTower::Audit::Event, :count)
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStateLimitReached)
      end

      context "when the fact already exists" do
        before do
          create(:user_experience_state, user:, host_key: "command_tower", experience_key:,
                                         scope_type:, scope_identifier:, version:)
        end

        it "replays with 200" do
          expect(result.http_status).to eq(:ok)
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
