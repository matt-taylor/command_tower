# frozen_string_literal: true

module CommandTower
  module CredentialResolution
    # Typed SMTP deployment credentials. Never log or serialize raw values.
    class SmtpCredentials
      attr_reader :user_name, :password

      def initialize(user_name:, password:)
        @user_name = user_name.to_s.strip
        @password = password.to_s.strip
        freeze
      end

      def available?
        user_name.present? && password.present?
      end

      def inspect
        "#<#{self.class.name} user_name=[REDACTED] password=[REDACTED] available?=#{available?}>"
      end

      alias_method :pretty_inspect, :inspect
    end
  end
end
