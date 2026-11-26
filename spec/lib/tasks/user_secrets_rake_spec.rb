# frozen_string_literal: true

require "rake"

RSpec.describe "command_tower:user_secrets:clear_plaintext", type: :task do
  let(:task_name) { "command_tower:user_secrets:clear_plaintext" }
  let(:user) { create(:user) }
  let(:reset_reason) { CommandTower::Secrets::PASSWORD_RESET }

  before do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    Rake::Task[task_name].clear if Rake::Task.task_defined?(task_name)
    load File.expand_path("../../../lib/tasks/user_secrets.rake", __dir__)
    Rake::Task[task_name].reenable
    allow($stdout).to receive(:puts)
  end

  context "with a legacy plaintext row" do
    let!(:legacy) { UserSecret.create!(user:, reason: "legacy", secret: "legacy-plaintext-token") }

    before { Rake::Task[task_name].invoke }

    it "blanks the plaintext", :aggregate_failures do
      expect(legacy.reload.secret).to be_nil
      expect($stdout).to have_received(:puts).with(/Cleared plaintext from 1 user secret/)
    end

    it "digests the plaintext" do
      expect(legacy.reload.secret_digest).to eq(UserSecret.digest_for("legacy-plaintext-token"))
    end
  end

  context "with a row that already has a digest" do
    let(:digest) { UserSecret.digest_for("already-digested") }
    let!(:existing) do
      UserSecret.create!(user:, reason: "legacy", secret: "already-digested", secret_digest: digest)
    end

    before { Rake::Task[task_name].invoke }

    it "blanks the plaintext and keeps the digest", :aggregate_failures do
      expect(existing.reload.secret).to be_nil
      expect(existing.secret_digest).to eq(digest)
    end
  end

  context "with a digest-only row" do
    let!(:digest_only) { create(:user_secret, user:) }
    let!(:before_attributes) { digest_only.reload.attributes }

    before { Rake::Task[task_name].invoke }

    it "leaves the row alone" do
      expect(digest_only.reload.attributes).to eq(before_attributes)
    end
  end

  context "with a cleared secret" do
    before do
      UserSecret.create!(user:, reason: reset_reason, secret: "redeem-me", use_count_max: 1)
      Rake::Task[task_name].invoke
    end

    it "still redeems by its original plaintext" do
      expect(CommandTower::Secrets::Verify.call(secret: "redeem-me", reason: reset_reason)).to be_success
    end
  end

  context "when run twice" do
    before do
      UserSecret.create!(user:, reason: "legacy", secret: "twice")
      Rake::Task[task_name].invoke
      Rake::Task[task_name].reenable
      Rake::Task[task_name].invoke
    end

    it "clears nothing the second time" do
      expect($stdout).to have_received(:puts).with(/Cleared plaintext from 0 user secret/)
    end
  end
end
