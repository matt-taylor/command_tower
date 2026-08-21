# frozen_string_literal: true

RSpec.describe CommandTower::ApplicationJob do
  it { expect(described_class.included_modules).to include(CommandTower::Execution::JobBoundary) }
end
