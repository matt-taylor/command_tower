# frozen_string_literal: true

RSpec.describe "CommandTower migration baseline" do
  let(:migrate_dir) { CommandTower::Engine.root.join("db/migrate") }
  let(:migration_basenames) { Dir.children(migrate_dir).grep(/\.rb\z/).sort }

  let(:expected_basenames) do
    %w[
      20260805000001_create_command_tower_users.rb
      20260805000002_create_command_tower_user_secrets.rb
      20260805000003_create_command_tower_messaging_core.rb
      20260805000004_create_messaging_notification_preferences.rb
      20260805000005_create_messaging_endpoints_and_pushover_credentials.rb
    ]
  end

  let(:expected_tables) do
    %w[
      users
      user_secrets
      messaging_communications
      messaging_destination_plans
      messaging_inbox_items
      messaging_channel_deliveries
      messaging_delivery_attempts
      messaging_notification_preferences
      messaging_endpoints
      messaging_endpoint_pushover_credentials
    ]
  end

  # Historical CT migrations → consolidated baseline disposition (5.2).
  let(:historical_disposition) do
    {
      "20241117043720_create_command_tower_users.rb" => "20260805000001",
      "20241204065708_create_command_tower_user_secrets.rb" => "20260805000002",
      "20250223023306_create_command_tower_messages.rb" => nil, # retired
      "20250223023313_create_command_tower_message_blasts.rb" => nil, # retired
      "20260723000001_create_command_tower_messaging_foundation.rb" => "20260805000003",
      "20260724000001_add_messaging_accept_persistence_fields.rb" => "20260805000003",
      "20260724045601_add_messaging_inbox_lifecycle_fields.rb" => "20260805000003",
      "20260724054301_add_messaging_delivery_attempt_ledger_fields.rb" => "20260805000003",
      "20260724054302_cutover_messaging_channel_delivery_execution_statuses.rb" => nil, # obsolete fresh
      "20260725000001_add_messaging_execution_handoff_status.rb" => "20260805000003",
      "20260725020001_add_messaging_channel_delivery_execution_fields.rb" => "20260805000003",
      "20260726000001_create_messaging_notification_preferences.rb" => "20260805000004",
      "20260727000001_create_messaging_endpoints.rb" => "20260805000005",
      "20260728000001_add_user_phone_identity_fields.rb" => "20260805000001",
      "20260730000001_create_messaging_endpoint_pushover_credentials.rb" => "20260805000005",
      "20260804000001_drop_legacy_messaging_tables.rb" => nil # obsolete fresh
    }
  end

  it "keeps only the compact final-schema baseline in the active migrate path" do
    expect(migration_basenames).to eq(expected_basenames)
  end

  context "when scanning active migration sources" do
    let(:sources) { migration_basenames.map { |name| File.read(migrate_dir.join(name)) } }

    it "never creates retired legacy messaging tables in active migrations" do
      expect(sources.join).not_to match(/create_table\s+:messages\b/)
      expect(sources.join).not_to match(/create_table\s+:message_blasts\b/)
    end
  end

  it "documents a disposition for every historical CT migration" do
    expect(historical_disposition.keys.size).to eq(16)
    historical_disposition.each_value do |owner|
      next if owner.nil?

      expect(expected_basenames.any? { |b| b.start_with?(owner) }).to be(true)
    end
  end

  context "when inspecting the live schema" do
    let(:tables) { ActiveRecord::Base.connection.data_sources }

    it "exposes every CT-owned domain table" do
      expect(tables).to include(*expected_tables)
      expect(tables).not_to include("messages", "message_blasts")
    end
  end

  it "aligns CT models with domain tables" do
    expect(User.table_name).to eq("users")
    expect(UserSecret.table_name).to eq("user_secrets")
    expect(CommandTower::Messaging::Communication.table_name).to eq("messaging_communications")
    expect(CommandTower::Messaging::DestinationPlan.table_name).to eq("messaging_destination_plans")
    expect(CommandTower::Messaging::InboxItem.table_name).to eq("messaging_inbox_items")
    expect(CommandTower::Messaging::ChannelDelivery.table_name).to eq("messaging_channel_deliveries")
    expect(CommandTower::Messaging::DeliveryAttempt.table_name).to eq("messaging_delivery_attempts")
    expect(CommandTower::Messaging::NotificationPreference.table_name).to eq("messaging_notification_preferences")
    expect(CommandTower::Messaging::Endpoint.table_name).to eq("messaging_endpoints")
    expect(CommandTower::Messaging::EndpointPushoverCredential.table_name).to eq(
      "messaging_endpoint_pushover_credentials"
    )
  end

  context "when inspecting users columns" do
    let(:columns) { ActiveRecord::Base.connection.columns("users").map(&:name) }

    it "includes final users phone identity columns" do
      expect(columns).to include("phone_number", "phone_number_validated")
    end
  end

  context "when inspecting messaging execution columns" do
    let(:communication_columns) { ActiveRecord::Base.connection.columns("messaging_communications").map(&:name) }
    let(:delivery_columns) { ActiveRecord::Base.connection.columns("messaging_channel_deliveries").map(&:name) }

    it "includes messaging execution and handoff columns on communications and deliveries" do
      expect(communication_columns).to include(
        "host_event_identity",
        "accept_request_fingerprint",
        "status",
        "execution_handoff_status"
      )
      expect(delivery_columns).to include("execution_claimed_at", "execution_attempt_count", "status")
    end
  end
end
