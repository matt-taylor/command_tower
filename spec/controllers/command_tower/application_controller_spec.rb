# frozen_string_literal: true

RSpec.describe CommandTower::ApplicationController do
  it { expect(described_class.included_modules).to include(CommandTower::Execution::HttpBoundary) }

  it "is the HTTP execution entrypoint for engine controllers" do
    expect(CommandTower::Auth::IdentityPolicyController.superclass).to eq(described_class)
  end
end
