# frozen_string_literal: true

module CommandTower
  module Auth
    AuthContext = Data.define(
      :user,
      :token_expires_at,
      :token_source,
      :roles,
      :principal_type,
      :generated_token
    ) do
      def initialize(user:, token_expires_at:, token_source:, roles:, principal_type:, generated_token: nil)
        super(
          user:,
          token_expires_at:,
          token_source:,
          roles:,
          principal_type:,
          generated_token:
        )
      end

      def self.from_authenticate_session_result(data:, metadata:)
        new(
          user: data[:user],
          token_expires_at: data[:token_expires_at],
          token_source: metadata[:token_source],
          roles: data[:user].roles,
          principal_type: :user,
          generated_token: data[:generated_token]
        )
      end
    end
  end
end
