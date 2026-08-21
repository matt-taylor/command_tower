# frozen_string_literal: true

module CommandTower
  module Logging
    class Subscriber < ActiveSupport::LogSubscriber
      PATTERNS = [
        /\Acommand_tower\.lifecycle(?:\.|\z)/,
        /\Acommand_tower\.log(?:\.|\z)/,
        /\Acommand_tower\.messaging(?:\.|\z)/
      ].freeze
      SEVERITIES = %i[debug info warn error].freeze

      class << self
        def logger
          @logger || super
        end

        def logger=(value)
          @logger = value
        end

        def attach!
          detach!
          subscriber = new
          @subscriptions = PATTERNS.map do |pattern|
            ActiveSupport::Notifications.subscribe(pattern) do |name, started, finished, id, payload|
              event = ActiveSupport::Notifications::Event.new(name, started, finished, id, payload)
              subscriber.call(event)
            end
          end
        end

        def detach!
          Array(@subscriptions).each { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
          @subscriptions = []
        end

        def subscriptions
          Array(@subscriptions)
        end
      end

      def call(event)
        return if logger.nil?
        return unless materialize?(event)

        severity = severity_for(event)
        logger.public_send(severity, log_entry(event))
      rescue StandardError
        begin
          logger&.error({ event: "command_tower.logging.subscriber_failed", error_class: $!.class.name })
        rescue StandardError
          nil
        end
      end

      def logger
        self.class.logger
      end

      private

      def materialize?(event)
        name = event.name
        return true if name.start_with?("command_tower.log.")
        return true if name.start_with?("command_tower.messaging.")
        return false unless name.start_with?("command_tower.lifecycle.")
        return false if name.end_with?(".started")

        outcome = (event.payload[:outcome] || event.payload["outcome"]).to_s
        return true if %w[failure error].include?(outcome)

        event.payload[:log_lifecycle] == true || event.payload["log_lifecycle"] == true
      end

      def log_entry(event)
        CommandTower::Logging::Projection.call(event)
      end

      def severity_for(event)
        name = event.name
        if name.start_with?("command_tower.log.")
          return named_severity(name.split(".").last)
        end

        payload_level = event.payload[:log_level] || event.payload["log_level"]
        return named_severity(payload_level) if payload_level

        return :debug if name.end_with?(".started")

        outcome = event.payload[:outcome] || event.payload["outcome"]
        return :error if outcome.to_s == "error"

        :info
      end

      def named_severity(value)
        level = value.to_sym
        SEVERITIES.include?(level) ? level : :info
      end
    end
  end
end
