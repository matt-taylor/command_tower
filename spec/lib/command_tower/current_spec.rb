# frozen_string_literal: true

RSpec.describe CommandTower::Current do
  after { described_class.reset }

  context "when unset" do
    it { expect(described_class.impersonation_active).to eq(false) }
  end

  context "when request_id is assigned" do
    before { described_class.request_id = "req-compat" }

    it { expect(described_class.request_id).to eq("req-compat") }
  end

  context "when reset after assignment" do
    before do
      described_class.user_id = 12
      described_class.remote_ip = "127.0.0.1"
      described_class.reset
    end

    it { expect(described_class.user_id).to be_nil }
    it { expect(described_class.remote_ip).to be_nil }
    it { expect(described_class.impersonation_active).to eq(false) }
  end
end
