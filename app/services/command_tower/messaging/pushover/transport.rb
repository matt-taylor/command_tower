# frozen_string_literal: true

module CommandTower
  module Messaging
    module Pushover
      # Selects Pushover provider transport from config. Provider ops only —
      # verification and delivery. Does not query endpoints, preferences, or
      # create DeliveryAttempts.
      module Transport
        class << self
          attr_writer :adapter

          def adapter
            @adapter ||= build_adapter
          end

          def reset_adapter!
            @adapter = nil
          end

          def validate_user!(user_key:, application_token:)
            adapter.validate_user!(user_key:, application_token:)
          end

          def send_test_notification!(user_key:, application_token:, title:, message:)
            adapter.send_test_notification!(
              user_key:,
              application_token:,
              title:,
              message:,
            )
          end

          def send_message!(user_key:, application_token:, title:, message:)
            adapter.send_message!(
              user_key:,
              application_token:,
              title:,
              message:,
            )
          end

          private

          def build_adapter
            name = CommandTower.config.messaging.pushover.adapter.to_s
            case name
            when "fake"
              Adapters::FakeAdapter.new
            when "log"
              Adapters::LogAdapter.new
            when "http"
              Adapters::HttpAdapter.new
            when "disabled"
              Adapters::DisabledAdapter.new
            else
              Adapters::DisabledAdapter.new
            end
          end
        end
      end
    end
  end
end
