# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Email
          class Configuration
            SUPPORTED_DELIVERY_METHODS = %i[test smtp].freeze
            SMTP_STRING_KEYS = %i[address user_name password authentication].freeze

            def self.email_configured?
              new.email_configured?
            end

            def email_configured?
              method = CommandTower.config.email.delivery_method
              method = method.to_sym if method.respond_to?(:to_sym)

              case method
              when :test
                true
              when :smtp
                smtp_contract_complete?
              else
                false
              end
            end

            private

            def smtp_contract_complete?
              settings = Rails.configuration.action_mailer.smtp_settings
              return false unless settings.is_a?(Hash)

              SMTP_STRING_KEYS.each do |key|
                value = settings[key] || settings[key.to_s]
                return false if value.nil? || value.to_s.strip.empty?
              end

              port = settings[:port] || settings["port"]
              return false unless port.is_a?(Integer)

              tls = settings[:enable_starttls_auto]
              tls = settings["enable_starttls_auto"] if tls.nil?
              return false unless tls == true || tls == false

              true
            end
          end
        end
      end
    end
  end
end
