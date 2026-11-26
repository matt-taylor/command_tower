# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::ExperienceStates::Completed do
  describe ".call" do
    subject(:result) do
      described_class.call(**fact.except(:host_key))
    end

    let(:user) { create(:user) }
    let(:host_key) { "command_tower" }
    let(:fact) do
      { user:, host_key: "command_tower", experience_key: "welcome", scope_type: "example_scope",
        scope_identifier: "42", version: "v1" }
    end

    around do |example|
      previous = CommandTower.config.application.host_key
      CommandTower.config.application.host_key = host_key
      example.run
    ensure
      CommandTower.config.application.host_key = previous
    end

    context "when host_key is blank" do
      let(:host_key) { "" }

      it "fails as unconfigured" do
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::ExperienceStatesHostUnconfiguredError)
      end
    end

    context "when the fact exists" do
      before { create(:user_experience_state, **fact) }

      it "reports completed" do
        expect(result.data[:completed]).to be(true)
      end
    end

    context "when no fact exists" do
      it "reports not completed" do
        expect(result.data[:completed]).to be(false)
      end
    end

    context "when the stored fact has another scope identifier" do
      before { create(:user_experience_state, **fact, scope_identifier: "99") }

      it "reports not completed" do
        expect(result.data[:completed]).to be(false)
      end
    end

    context "when the stored fact has another version" do
      before { create(:user_experience_state, **fact, version: "v0") }

      it "reports not completed" do
        expect(result.data[:completed]).to be(false)
      end
    end

    context "when the stored fact belongs to another user" do
      before { create(:user_experience_state, **fact, user: create(:user)) }

      it "reports not completed" do
        expect(result.data[:completed]).to be(false)
      end
    end

    context "when the stored fact has another host_key" do
      before { create(:user_experience_state, **fact, host_key: "elsewhere") }

      it "reports not completed" do
        expect(result.data[:completed]).to be(false)
      end
    end
  end
end
