# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::AdminUnavailableDuringImpersonationError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("admin_unavailable_during_impersonation") }
  it { expect(error.message).to eq("Admin tools are unavailable while impersonating a user.") }
  it { expect(error.log_level).to eq(:info) }
end
