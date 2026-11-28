# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Inbox::BadgeSyncScheduler do
  let(:job_class) do
    Class.new do
      def self.set(**) = self
      def self.perform_later(*); end
    end
  end
  let(:marker_key) { described_class.marker_key(7) }

  before do
    CommandTower::RedisConnection.with(&:flushdb)
    stub_const("CommandTower::Messaging::Inbox::BadgeSyncJob", job_class)
    allow(job_class).to receive(:set).and_call_original
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

    it "enqueues with a short wait" do
      described_class.schedule_after_commit(7)

      expect(job_class).to have_received(:set).with(wait: described_class::ENQUEUE_WAIT)
    end

    it "takes the pending marker at enqueue time" do
      described_class.enqueue(7)

      expect(CommandTower::RedisConnection.with { |redis| redis.exists?(marker_key) }).to be(true)
    end

    it "coalesces a burst into one enqueue" do
      3.times { described_class.enqueue(7) }

      expect(job_class).to have_received(:perform_later).once
    end

    it "enqueues again once the marker is cleared" do
      described_class.enqueue(7)
      CommandTower::RedisConnection.with { |redis| redis.del(marker_key) }
      described_class.enqueue(7)

      expect(job_class).to have_received(:perform_later).twice
    end

    context "when Redis is down" do
      before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

      it "fails open and enqueues" do
        described_class.enqueue(7)

        expect(job_class).to have_received(:perform_later).with(7)
      end
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
