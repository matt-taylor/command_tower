# frozen_string_literal: true

# Cross-class checks over the four experience state errors; per-class specs sit beside this file.
RSpec.describe CommandTower::Errors::Account do # rubocop:disable RSpec/SpecFilePathFormat
  describe "experience state errors" do
    let(:error_classes) do
      [
        CommandTower::Errors::Account::ExperienceStateImpersonationForbidden,
        CommandTower::Errors::Account::ExperienceStateUnregistered,
        CommandTower::Errors::Account::ExperienceStateRateLimited,
        CommandTower::Errors::Account::ExperienceStateLimitReached
      ]
    end

    let(:initializer_param_names) do
      error_classes.flat_map { |klass| klass.instance_method(:initialize).parameters.map(&:last) }
    end

    it "accepts no submitted input, so messages cannot echo a key or identifier" do
      expect(initializer_param_names - [:retry_after_seconds]).not_to include(:key, :experience_key, :scope_identifier)
    end

    it "uses distinct codes" do
      expect(error_classes.map { |klass| klass.new.code }.uniq.size).to eq(4)
    end
  end
end
