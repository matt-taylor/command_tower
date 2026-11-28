# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Accept::ThreadRestorer, :messaging_accept, :messaging_thread_restore do
  self.use_transactional_tests = false

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:option) { true }

  around do |example|
    DatabaseCleaner.clean_with(:truncation)
    example.run
    DatabaseCleaner.clean_with(:truncation)
  end

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "booking.success",
        allowed_channels: %w[email],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: { "channels" => { "email" => true }, "inbox" => true }
      )
    )
    CommandTower.config.messaging.inbox.restore_archived_thread_on_new_message = option
  end

  after { CommandTower.config.messaging.inbox.restore_archived_thread_on_new_message = false }

  it "defaults to off, matching today's behaviour" do
    expect(CommandTower::Configuration::Messaging::Inbox.new.restore_archived_thread_on_new_message).to be(false)
  end

  context "when the option is off" do
    let(:option) { false }
    let(:first) { archived_accept_in_thread }

    before do
      first
      accept_in_thread
    end

    it "leaves archived members archived" do
      expect(inbox_item_archived?(first)).to be(true)
    end
  end

  context "when the option is on with archived unread and read members" do
    let(:unread) { archived_accept_in_thread }
    let(:read) { accept_in_thread.tap { |result| archive_inbox_item(result, viewed_at: Time.current) } }

    before do
      unread
      read
      accept_in_thread
    end

    it "restores an unread member to created" do
      expect(reloaded_inbox_item(unread)).to have_attributes(archived_at: nil, status: "created")
    end

    it "restores a read member to viewed" do
      expect(reloaded_inbox_item(read)).to have_attributes(archived_at: nil, status: "viewed")
    end
  end

  context "when members are resolved or deleted" do
    let(:resolved) { accept_in_thread.tap { |result| archive_inbox_item(result, resolved_at: Time.current) } }
    let(:deleted) { accept_in_thread.tap { |result| archive_inbox_item(result, deleted_at: Time.current) } }

    before do
      resolved
      deleted
      accept_in_thread
    end

    it "keeps resolved rows archived" do
      expect(inbox_item_archived?(resolved)).to be(true)
    end

    it "keeps deleted rows archived" do
      expect(inbox_item_archived?(deleted)).to be(true)
    end
  end

  context "when other conversations and recipients are archived" do
    let(:other_thread) { archived_accept_in_thread(conversation_key: "week-6") }
    let(:other_recipient) { archived_accept_in_thread(recipient: other_user) }

    before do
      other_thread
      other_recipient
      accept_in_thread
    end

    it "leaves another conversation alone" do
      expect(inbox_item_archived?(other_thread)).to be(true)
    end

    it "leaves another recipient alone" do
      expect(inbox_item_archived?(other_recipient)).to be(true)
    end
  end

  context "without a conversation_key" do
    let(:keyless) { archived_accept_in_thread(conversation_key: nil) }

    before do
      keyless
      accept_in_thread(conversation_key: nil)
    end

    it "restores nothing" do
      expect(inbox_item_archived?(keyless)).to be(true)
    end
  end

  context "when the same event is replayed" do
    let(:first) { archived_accept_in_thread(identity: "same-event") }
    let(:replay) { accept_in_thread(identity: "same-event") }

    before { first }

    it "reports a replay" do
      expect(replay.idempotent_replay).to be(true)
    end

    it "never restores" do
      replay
      expect(inbox_item_archived?(first)).to be(true)
    end
  end

  context "when Accept runs inside a transaction that rolls back" do
    let(:first) { archived_accept_in_thread }

    before do
      first
      ActiveRecord::Base.transaction do
        accept_in_thread
        raise ActiveRecord::Rollback
      end
    end

    it "does not restore" do
      expect(inbox_item_archived?(first)).to be(true)
    end
  end

  context "when the restore deadlocks once" do
    let(:first) { archived_accept_in_thread }
    let(:attempts) { [] }

    before do
      first
      stub_restore_members do |inner|
        attempts << :attempt
        raise ActiveRecord::Deadlocked, "stubbed" if attempts.one?

        inner.call
      end
      accept_in_thread
    end

    it "retries inside the step" do
      expect(attempts.size).to eq(2)
    end

    it "restores on the retry" do
      expect(inbox_item_archived?(first)).to be(false)
    end
  end

  context "when the restore keeps deadlocking" do
    let(:first) { archived_accept_in_thread }
    let(:result) { accept_in_thread }

    before do
      first
      stub_restore_members { raise ActiveRecord::Deadlocked, "stubbed" }
    end

    it "still accepts the message" do
      expect(result.inbox_item_id).to be_present
    end

    it "leaves the thread archived" do
      result
      expect(inbox_item_archived?(first)).to be(true)
    end
  end

  context "when locking members" do
    let(:statements) { [] }

    before do
      archived_accept_in_thread
      callback = ->(*, payload) { statements << payload[:sql] if payload[:sql].include?("FOR UPDATE") }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { accept_in_thread }
    end

    it "orders by id with FOR UPDATE in one statement" do
      expect(statements).to match([/ORDER BY .*`id`.* FOR UPDATE/])
    end
  end
end
