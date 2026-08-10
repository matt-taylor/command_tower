# frozen_string_literal: true

module CommandTower
  module CredentialResolution
    # Typed Twilio deployment credentials. Never log or serialize raw values.
    class TwilioCredentials
      attr_reader :account_sid, :auth_token

      def initialize(account_sid:, auth_token:)
        @account_sid = account_sid.to_s.strip
        @auth_token = auth_token.to_s.strip
        freeze
      end

      def available?
        account_sid.present? && auth_token.present?
      end

      def inspect
        "#<#{self.class.name} account_sid=[REDACTED] auth_token=[REDACTED] available?=#{available?}>"
      end

      alias_method :pretty_inspect, :inspect
    end
  end
end
