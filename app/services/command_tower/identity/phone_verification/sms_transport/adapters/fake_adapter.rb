# frozen_string_literal: true

module CommandTower
  module Identity
    module PhoneVerification
      module SmsTransport
        module Adapters
          # In-memory / no-network adapter for tests and local default.
          class FakeAdapter
            class << self
              attr_accessor :deliveries, :fail_with

              def reset!
                self.deliveries = []
                self.fail_with = nil
              end
            end

            self.reset!

            def deliver(to:, body:)
              if self.class.fail_with
                code, message = self.class.fail_with
                return SmsTransport::Result.new(success?: false, error_code: code, error_message: message)
              end

              self.class.deliveries << { to: to, body: body }
              SmsTransport::Result.new(success?: true, error_code: nil, error_message: nil)
            end
          end
        end
      end
    end
  end
end
