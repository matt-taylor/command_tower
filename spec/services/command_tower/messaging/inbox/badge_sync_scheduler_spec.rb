# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Inbox::BadgeSyncScheduler do
  let(:job_class) { Class.new { def self.perform_later(*); end } }

  before do
    stub_const("CommandTower::Messaging::Inbox::BadgeSyncJob", job_class)
    allow(job_class).to receive(:perform_later)
  end

  after { CommandTower.config.messaging.inbox.badge_sync_push = false }

  it "defaults the flag to off" do
    expect(CommandTower::Configuration::Messaging::Inbox.new.badge_sync_push).to be(false)
  end

  it "enqueues nothing when the flag is off" do
    described_class.schedule_after_commit(7)

    expect(job_class).not_to have_received(:perform_later)
  end

  context "when the flag is on" do
    before { CommandTower.config.messaging.inbox.badge_sync_push = true }

    it "enqueues the job with the user id only" do
      described_class.schedule_after_commit(7)

      expect(job_class).to have_received(:perform_later).with(7)
    end

    it "defers the enqueue until the outer transaction commits" do
      ActiveRecord::Base.transaction do
        described_class.schedule_after_commit(7)
        expect(job_class).not_to have_received(:perform_later)
      end
    end

    it "enqueues nothing while impersonating" do
      CommandTower::Current.set(impersonation_active: true) do
        described_class.schedule_after_commit(7)
      end

      expect(job_class).not_to have_received(:perform_later)
    end

    context "when the enqueue fails" do
      before { allow(job_class).to receive(:perform_later).and_raise(StandardError, "queue down") }

      it "swallows the failure" do
        expect { described_class.enqueue(7) }.not_to raise_error
      end
    end
  end
end
