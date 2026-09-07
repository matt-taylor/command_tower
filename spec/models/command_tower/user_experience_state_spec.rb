# frozen_string_literal: true

RSpec.describe CommandTower::UserExperienceState do
  describe "factory" do
    subject(:state) { create(:user_experience_state) }

    it "is valid" do
      expect(state).to be_persisted
      expect(state.user).to be_present
      expect(state.host_key).to eq("command_tower")
      expect(state.experience_key).to eq("welcome")
      expect(state.completed_at).to be_present
    end
  end

  describe "associations and validations" do
    subject(:state) do
      build(
        :user_experience_state,
        user:,
        host_key:,
        experience_key:,
        scope_type:,
        scope_identifier:,
        version:,
      )
    end

    let(:user) { create(:user) }
    let(:host_key) { "command_tower" }
    let(:experience_key) { "welcome" }
    let(:scope_type) { "example_scope" }
    let(:scope_identifier) { "42" }
    let(:version) { "v1" }

    it "belongs to user" do
      expect(state.user).to eq(user)
    end

    %i[host_key experience_key scope_type scope_identifier version].each do |attribute|
      context "when #{attribute} is blank" do
        let(attribute) { "" }

        it "is invalid" do
          expect(state).not_to be_valid
          expect(state.errors[attribute]).to be_present
        end
      end
    end

    context "when the composite identity is already taken" do
      before do
        create(
          :user_experience_state,
          user:,
          host_key:,
          experience_key:,
          scope_type:,
          scope_identifier:,
          version:,
        )
      end

      it "is invalid" do
        expect(state).not_to be_valid
        expect(state.errors[:experience_key]).to be_present
      end
    end

    context "when only the scope identifier differs" do
      before do
        create(
          :user_experience_state,
          user:,
          host_key:,
          experience_key:,
          scope_type:,
          scope_identifier: "99",
          version:,
        )
      end

      it "is valid" do
        expect(state).to be_valid
      end
    end
  end

  describe ".for_user_and_host" do
    let(:user) { create(:user) }
    let!(:matching) { create(:user_experience_state, user:, host_key: "command_tower") }
    let!(:other_host) { create(:user_experience_state, user:, host_key: "other_host", scope_identifier: "other") }

    it "returns only rows for the configured host" do
      expect(described_class.for_user_and_host(user:, host_key: "command_tower")).to contain_exactly(matching)
      expect(described_class.for_user_and_host(user:, host_key: "command_tower")).not_to include(other_host)
    end
  end
end
