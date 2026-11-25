# frozen_string_literal: true

RSpec.describe CommandTower::Current do
  after { described_class.reset }

  context "when unset" do
    it { expect(described_class.impersonation_active).to eq(false) }
  end

  context "when ui_catalog is unset" do
    it { expect(described_class.ui_catalog).to eq(1) }
  end

  context "when scanning for readers of ui_catalog" do
    let(:root) { Pathname.new(File.expand_path("../../..", __dir__)) }
    let(:allowed_readers) do
      %w[
        app/workflows/command_tower/workflows/messaging/inbox.rb
        app/workflows/command_tower/workflows/home_notices/show_workflow.rb
        app/workflows/command_tower/workflows/home_notices/record_impression_workflow.rb
        app/workflows/command_tower/workflows/home_notices/acknowledge_workflow.rb
        app/workflows/command_tower/workflows/home_notices/dismiss_workflow.rb
      ]
    end
    let(:readers) do
      paths = Dir[root.join("{app,lib}/**/*.rb")].grep_v(/\.keep\z/)
      matching = paths.select { |path| File.read(path).match?(/Current\.ui_catalog\b(?!\s*=)/) }
      matching.map { |path| Pathname.new(path).relative_path_from(root).to_s }
    end

    it "has none beyond the inbox and home notices workflows (never used for authorization)" do
      expect(readers - allowed_readers).to eq([])
    end
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
