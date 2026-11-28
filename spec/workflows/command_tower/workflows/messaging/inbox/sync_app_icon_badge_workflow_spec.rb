# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Messaging::Inbox::SyncAppIconBadgeWorkflow do
  subject(:invoke) { described_class.call(user_id: user.id) }

  let(:user) { create(:user) }
  let(:token) { "ExponentPushToken[badgesync0001]" }
  let(:client) { instance_double(CommandTower::Messaging::Execution::Adapters::Expo::HttpClient) }
  let(:badge_result) { instance_double(CommandTower::Messaging::Inbox::UnreadCountResult, badge_count: 3) }
  let(:marker_key) { "command_tower:messaging:inbox:badge_sync:pending:#{user.id}" }

  around do |example|
    original_adapter = CommandTower.config.messaging.expo.adapter
    example.run
  ensure
    CommandTower.config.messaging.expo.adapter = original_adapter
  end

  before do
    CommandTower::RedisConnection.with(&:flushdb)
    CommandTower.config.messaging.inbox.badge_sync_push = true
    CommandTower.config.messaging.expo.adapter = "http"
    allow(CommandTower::Messaging::Execution::Adapters::Expo::HttpClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_messages).and_return({ ok: true, status_code: 200, tickets: [] })
    allow(CommandTower::Messaging::Inbox).to receive(:unread_count).and_return(badge_result)
  end

  after do
    CommandTower.config.messaging.inbox.badge_sync_push = false
    CommandTower::Current.reset
  end

  context "with a verified push device" do
    before { create(:messaging_endpoint, :verified, user:, push_token: token) }

    it "succeeds" do
      expect(invoke).to be_success
    end

    it "sends only {to, badge}" do
      invoke

      expect(client).to have_received(:send_messages).with([{ "to" => token, "badge" => 3 }])
    end

    it "sends again for a change after the previous send (trailing edge)" do
      2.times { described_class.call(user_id: user.id) }

      expect(client).to have_received(:send_messages).twice
    end

    it "sends nothing while impersonating" do
      CommandTower::Current.impersonation_active = true

      invoke

      expect(client).not_to have_received(:send_messages)
    end

    context "when the scheduler's pending marker is held" do
      before { CommandTower::RedisConnection.with { |redis| redis.set(marker_key, "1", nx: true, ex: 60) } }

      it "sends and clears the marker" do
        invoke

        expect(CommandTower::RedisConnection.with { |redis| redis.exists?(marker_key) }).to be(false)
      end
    end

    context "when reading the count" do
      before do
        allow(CommandTower::Messaging::Inbox).to receive(:unread_count) do
          raise "marker still held" if CommandTower::RedisConnection.with { |redis| redis.exists?(marker_key) }

          badge_result
        end
      end

      it "clears the marker before reading the count" do
        invoke

        expect(client).to have_received(:send_messages).with([{ "to" => token, "badge" => 3 }])
      end
    end

    context "when Redis is down" do
      before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

      it "fails open and still sends" do
        invoke

        expect(client).to have_received(:send_messages).once
      end
    end

    context "when the flag is off" do
      before { CommandTower.config.messaging.inbox.badge_sync_push = false }

      it "sends nothing" do
        invoke

        expect(client).not_to have_received(:send_messages)
      end
    end

    context "when the Expo adapter is not http" do
      before { CommandTower.config.messaging.expo.adapter = "fake" }

      it "sends nothing" do
        invoke

        expect(client).not_to have_received(:send_messages)
      end
    end

    context "when the unread count is zero" do
      let(:badge_result) { instance_double(CommandTower::Messaging::Inbox::UnreadCountResult, badge_count: 0) }

      it "sends a zero badge" do
        invoke

        expect(client).to have_received(:send_messages).with([{ "to" => token, "badge" => 0 }])
      end
    end

    context "when the send raises" do
      before do
        allow(Rails.logger).to receive(:warn)
        allow(client).to receive(:send_messages).and_raise(StandardError, token)
      end

      it "swallows the error" do
        expect(invoke).to be_success
      end

      it "logs the class only, never the token" do
        invoke

        expect(Rails.logger).to have_received(:warn).with(satisfy { |line| line.exclude?(token) })
      end
    end
  end

  context "with an unverified push device" do
    before { create(:messaging_endpoint, user:, push_token: token) }

    it "sends nothing" do
      invoke

      expect(client).not_to have_received(:send_messages)
    end
  end
end
