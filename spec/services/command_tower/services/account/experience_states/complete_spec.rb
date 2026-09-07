# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::ExperienceStates::Complete do
  describe ".call" do
    subject(:result) do
      described_class.call(
        user:,
        experience_key:,
        scope_type:,
        scope_identifier:,
        version:,
      )
    end

    let(:user) { create(:user) }
    let(:experience_key) { "welcome" }
    let(:scope_type) { "example_scope" }
    let(:scope_identifier) { "42" }
    let(:version) { "v1" }

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

    context "when completing for the first time" do
      it "creates a durable completion fact" do
        expect(result).to be_success
        expect(result.data[:created]).to be(true)
        expect(result.data[:experience_state]).to have_attributes(
          user_id: user.id,
          host_key: "command_tower",
          experience_key: "welcome",
          scope_type: "example_scope",
          scope_identifier: "42",
          version: "v1",
        )
        expect(result.data[:experience_state].completed_at).to be_present
      end
    end

    context "when replaying the same completion" do
      let!(:existing) do
        create(
          :user_experience_state,
          user:,
          host_key: "command_tower",
          experience_key:,
          scope_type:,
          scope_identifier:,
          version:,
          completed_at: 2.days.ago.change(usec: 0),
        )
      end

      it "returns the existing row without changing completed_at" do
        expect(result).to be_success
        expect(result.data[:created]).to be(false)
        expect(result.data[:experience_state].id).to eq(existing.id)
        expect(result.data[:experience_state].completed_at).to eq(existing.completed_at)
      end
    end

    context "when completing a different scope" do
      before do
        create(
          :user_experience_state,
          user:,
          host_key: "command_tower",
          experience_key:,
          scope_type:,
          scope_identifier: "99",
          version:,
        )
      end

      it "creates an independent completion" do
        expect(result).to be_success
        expect(result.data[:created]).to be(true)
        expect(result.data[:experience_state].scope_identifier).to eq("42")
      end
    end

    context "when completing a different version" do
      before do
        create(
          :user_experience_state,
          user:,
          host_key: "command_tower",
          experience_key:,
          scope_type:,
          scope_identifier:,
          version: "v0",
        )
      end

      it "creates an independent completion" do
        expect(result).to be_success
        expect(result.data[:created]).to be(true)
        expect(result.data[:experience_state].version).to eq("v1")
      end
    end

    context "when a concurrent insert wins the unique race" do
      let!(:existing) do
        create(
          :user_experience_state,
          user:,
          host_key: "command_tower",
          experience_key:,
          scope_type:,
          scope_identifier:,
          version:,
          completed_at: 1.day.ago.change(usec: 0),
        )
      end

      before do
        allow(CommandTower::UserExperienceState).to receive(:find_by).and_call_original
        allow(CommandTower::UserExperienceState).to receive(:find_by)
          .with(hash_including(experience_key:, scope_identifier:))
          .and_return(nil, existing)
        allow(CommandTower::UserExperienceState).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        allow(CommandTower::UserExperienceState).to receive(:find_by!)
          .with(hash_including(experience_key:, scope_identifier:))
          .and_return(existing)
      end

      it "recovers the existing row and reports created false" do
        expect(result).to be_success
        expect(result.data[:created]).to be(false)
        expect(result.data[:experience_state]).to eq(existing)
      end
    end
  end
end
