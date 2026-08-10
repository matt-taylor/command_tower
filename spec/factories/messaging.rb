# frozen_string_literal: true

FactoryBot.define do
  factory :messaging_communication, class: "CommandTower::Messaging::Communication" do
    user
    notification_type_key { "example.type" }
    sequence(:title) { |n| "Message title #{n}" }
    sequence(:body) { |n| "Message body #{n}." }
    metadata { nil }
    execution_handoff_status { CommandTower::Messaging::Communication::HANDOFF_COMPLETE }

    trait :with_destination_plan do
      after(:create) do |communication|
        create(:messaging_destination_plan, communication:)
      end
    end

    trait :with_inbox_item do
      after(:create) do |communication|
        create(:messaging_inbox_item, communication:)
      end
    end

    trait :handoff_pending do
      execution_handoff_status { CommandTower::Messaging::Communication::HANDOFF_PENDING }
    end
  end

  factory :messaging_destination_plan, class: "CommandTower::Messaging::DestinationPlan" do
    communication factory: :messaging_communication
    decision do
      {
        "selected_channels" => %w[email],
        "inbox_selected" => false,
        "mandatory" => false,
        "platform_enabled_channels" => %w[email],
        "excluded_destinations" => [],
      }
    end
  end

  factory :messaging_inbox_item, class: "CommandTower::Messaging::InboxItem" do
    communication factory: :messaging_communication
    status { CommandTower::Messaging::InboxItem::STATUS_CREATED }

    trait :viewed do
      viewed_at { Time.current }
      status { CommandTower::Messaging::InboxItem::STATUS_VIEWED }
    end

    trait :archived do
      archived_at { Time.current }
      status { CommandTower::Messaging::InboxItem::STATUS_ARCHIVED }
    end

    trait :deleted do
      deleted_at { Time.current }
      status { CommandTower::Messaging::InboxItem::STATUS_DELETED }
    end
  end

  factory :messaging_channel_delivery, class: "CommandTower::Messaging::ChannelDelivery" do
    communication factory: :messaging_communication
    channel_key { "email" }
  end

  factory :messaging_delivery_attempt, class: "CommandTower::Messaging::DeliveryAttempt" do
    channel_delivery factory: :messaging_channel_delivery
    status { CommandTower::Messaging::DeliveryAttempt::STATUS_STARTED }
    started_at { Time.current }
  end

  factory :messaging_notification_preference, class: "CommandTower::Messaging::NotificationPreference" do
    user
    notification_type_key { "example.type" }
    state { { "channels" => {}, "inbox" => true } }
  end

  factory :messaging_endpoint, class: "CommandTower::Messaging::Endpoint" do
    user
    channel_key { "push" }
    lifecycle_state { "active" }
    verification_state { "unverified" }

    transient do
      sequence(:push_token) { |n| "ExponentPushToken[factory#{n.to_s.rjust(8, '0')}]" }
      pushover_user_key { "pushover-user-key-abcd" }
      pushover_application_token { "pushover-app-token-zzzz" }
    end

    address_ciphertext do
      CommandTower::Messaging::Endpoints::SecretBox.encrypt(push_token).fetch(:ciphertext)
    end
    address_fingerprint do
      CommandTower::Messaging::Endpoints::Fingerprinter.fingerprint(push_token)
    end
    masked_display_value { "Device registered" }
    encryption_key_version { CommandTower::Messaging::Endpoints::SecretBox.key_version }

    trait :pushover do
      channel_key { "pushover" }
      address_ciphertext { nil }
      address_fingerprint do
        CommandTower::Messaging::Endpoints::Fingerprinter.fingerprint(
          "#{pushover_user_key}\n#{pushover_application_token}",
        )
      end
      masked_display_value do
        key = pushover_user_key.to_s
        key.length >= 4 ? "#{"•" * 8}#{key[-4, 4]}" : "configured"
      end
      encryption_key_version { CommandTower::Messaging::Endpoints::SecretBox.key_version }
    end

    trait :revoked do
      lifecycle_state { "revoked" }
      revoked_at { Time.current }
    end

    trait :verified do
      verification_state { "verified" }
      verified_at { Time.current }
    end
  end

  factory :messaging_endpoint_pushover_credential,
          class: "CommandTower::Messaging::EndpointPushoverCredential" do
    transient do
      pushover_user_key { "pushover-user-key-abcd" }
      pushover_application_token { "pushover-app-token-zzzz" }
    end

    endpoint do
      association(
        :messaging_endpoint,
        :pushover,
        pushover_user_key:,
        pushover_application_token:,
      )
    end

    user_key_ciphertext do
      CommandTower::Messaging::Endpoints::SecretBox.encrypt(
        pushover_user_key,
        purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_USER_KEY_PURPOSE,
      ).fetch(:ciphertext)
    end
    application_token_ciphertext do
      CommandTower::Messaging::Endpoints::SecretBox.encrypt(
        pushover_application_token,
        purpose: CommandTower::Messaging::Endpoints::SecretBox::PUSHOVER_APPLICATION_TOKEN_PURPOSE,
      ).fetch(:ciphertext)
    end
    encryption_key_version { CommandTower::Messaging::Endpoints::SecretBox.key_version }
  end
end
