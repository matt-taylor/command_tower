# frozen_string_literal: true

module ApiEngineBase
  module Configuration
    module Email
      class Config < ::ApiEngineBase::Configuration::Base
        include ClassComposer::Generator

        ASSIGNMENT = Proc.new do |key, value|
          hash = Rails.configuration.action_mailer.smtp_settings ||= {}
          Rails.configuration.action_mailer.smtp_settings = hash.merge({key => value})
        end

        ACTION_MAILER = Proc.new do |key, value|
          Rails.configuration.action_mailer.public_send(:"#{key}=", value)
        end

        add_composer :user_name,
          desc: "User Name for email. Defaults to ENV['GMAIL_USER_NAME']",
          allowed: String,
          default: ENV.fetch("GMAIL_USER_NAME", ""),
          default_shown: "ENV[\"GMAIL_USER_NAME\"]",
          &ASSIGNMENT

        add_composer :password,
          desc: "Password for email. Defaults to ENV['GMAIL_PASSWORD']. For more info on how to get this for GMAIL...https://support.google.com/accounts/answer/185833",
          allowed: String,
          default: ENV.fetch("GMAIL_PASSWORD", ""),
          default_shown: "ENV[\"GMAIL_PASSWORD\"]",
          &ASSIGNMENT

        add_composer :port,
          allowed: Integer,
          default: 587,
          &ASSIGNMENT

        add_composer :address,
          desc: "SMTP address for email. Defaults to smtp.gmail.com",
          allowed: String,
          default: "smtp.gmail.com",
          &ASSIGNMENT

        add_composer :authentication,
          desc: "Authentication type for email",
          allowed: String,
          default: "plain",
          &ASSIGNMENT

        add_composer :enable_starttls_auto,
          allowed: [TrueClass, FalseClass],
          default: true,
          &ASSIGNMENT

        add_composer :delivery_method,
          allowed: Symbol,
          default: Rails.env.test? ? :test : :smtp,
          &ACTION_MAILER

        add_composer :perform_deliveries,
          allowed: [TrueClass, FalseClass],
          default: true,
          &ACTION_MAILER

        add_composer :raise_delivery_errors,
          allowed: [TrueClass, FalseClass],
          default: true,
          &ACTION_MAILER

        def gmail!(
          from: ENV["GMAIL_USER_NAME"],
          password: ENV["GMAIL_PASSWORD"],
          port: 587,
          address: "smtp.gmail.com",
          authentication: "plain",
          enable_starttls_auto: true
        )
          method(:from=).call(from)
          method(:password=).call(password)
          method(:port=).call(port)
          method(:address=).call(address)
          method(:authentication=).call(authentication)
          method(:enable_starttls_auto=).call(enable_starttls_auto)
        end
      end
    end
  end
end
