# frozen_string_literal: true

RSpec.describe CommandTower::Services::Messaging::Communications::ProduceMany, :messaging_accept do
  let(:users) { create_list(:user, 2) }
  let(:user_ids) { users.map(&:id) }
  let(:notification_type_key) { "promo.test" }
  let(:campaign_identity) { "campaign/test-1" }
  let(:title) { "Hello" }
  let(:body) { "Book here: https://example.com/deeplink/1" }
  let(:platform_enabled_channels) { [] }
  let(:execution_mode) { :sync }

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email sms],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => true,
        },
      ),
    )
  end

  let(:call_service) do
    lambda do |**overrides|
      described_class.call(
        user_ids:,
        notification_type_key:,
        campaign_identity:,
        title:,
        body:,
        platform_enabled_channels:,
        execution_mode:,
        **overrides
      )
    end
  end

  context "with an empty audience" do
    subject(:result) { call_service.call(user_ids: []) }

    it "accepts an empty audience" do
      expect(result).to be_success
      expect(result.data).to include(mode: :sync, requested: 0, accepted: 0, failed: 0, skipped: 0)
    end
  end

  context "in sync mode with two users" do
    subject(:result) { call_service.call }

    it "produces one communication per user id in sync mode" do
      expect(result).to be_success
      expect(result.data).to include(requested: 2, accepted: 2, failed: 0, skipped: 0, mode: :sync)
      users.each do |user|
        expect(
          CommandTower::Messaging::Communication.find_by(
            user_id: user.id,
            host_event_identity: "#{campaign_identity}/#{user.id}",
          )
        ).to be_present
      end
    end
  end

  context "when some user ids are missing" do
    subject(:result) { call_service.call(user_ids: [users.first.id, 9_999_999_999]) }

    it "skips missing user ids" do
      expect(result).to be_success
      expect(result.data).to include(accepted: 1, skipped: 1, failed: 0)
    end
  end

  context "when sync mode exceeds the cap" do
    let(:ids) { (1..26).to_a }

    subject(:result) { call_service.call(user_ids: ids, execution_mode: :sync) }

    it "rejects sync mode above the cap" do
      expect(result).to be_failure
      expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
    end
  end

  context "in async mode" do
    subject(:result) { call_service.call(execution_mode: :async) }

    it "enqueues recipient jobs in async mode without claiming Produce completion" do
      expect(result).to be_success
      expect(result.data).to include(
        mode: :async,
        requested: 2,
        enqueued: 2,
        enqueue_failed: 0,
        campaign_identity:,
      )
      expect(result.data).not_to have_key(:accepted)
      expect(CommandTower::Messaging::Communications::ProduceRecipientJob).to have_been_enqueued.exactly(2).times
    end
  end

  context "when one Produce call fails" do
    before do
      allow(CommandTower::Services::Messaging::Communications::Produce).to receive(:call).and_wrap_original do |method, **kwargs|
        if kwargs[:user].id == users.last.id
          CommandTower::Services::ServiceResult.failure(errors: [CommandTower::Errors::InternalError.new])
        else
          method.call(**kwargs)
        end
      end
    end

    subject(:result) { call_service.call }

    it "isolates individual Produce failures" do
      expect(result).to be_success
      expect(result.data).to include(accepted: 1, failed: 1, skipped: 0)
    end
  end
end
