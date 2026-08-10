# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      # Provider adapter selection (fake override → channel configuration → UnconfiguredAdapter).
      class SelectAdapter
        def self.call(delivery:, executor: nil)
          new(delivery:, executor:).call
        end

        def initialize(delivery:, executor: nil)
          @delivery = delivery
          @executor = executor
        end

        def call
          @executor || default_adapter
        end

        private

        def default_adapter
          # Platform testing override (not provider configuration). Precedence:
          # injected executor → allow_fake_adapter → provider selection.
          if CommandTower.config.messaging.allow_fake_adapter
            return Adapters::FakeAdapter.new
          end

          case @delivery.channel_key.to_s
          when "email"
            return Adapters::Email::Adapter.new if Adapters::Email::Configuration.email_configured?
          when "sms"
            return sms_runtime_adapter
          when "pushover"
            if Adapters::Pushover::Configuration.pushover_configured?
              return Adapters::Pushover::Adapter.new
            end
          end

          Adapters::UnconfiguredAdapter.new
        end

        def sms_runtime_adapter
          case Adapters::Sms::Configuration.new.adapter_name
          when "twilio"
            if Adapters::Sms::Configuration.sms_configured?
              Adapters::Sms::Adapter.new
            else
              Adapters::UnconfiguredAdapter.new
            end
          when "fake"
            Adapters::FakeAdapter.new
          when "log"
            Adapters::Sms::LogAdapter.new
          else
            Adapters::UnconfiguredAdapter.new
          end
        end
      end
    end
  end
end
