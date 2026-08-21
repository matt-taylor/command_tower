# frozen_string_literal: true

module CommandTower
  module Auth
    AuthContext = Data.define(
      :user,
      :token_expires_at,
      :token_source,
      :roles,
      :principal_type,
      :generated_token,
      :actor_user,
      :impersonation_session_id
    ) do
      def initialize(user:, token_expires_at:, token_source:, roles:, principal_type:, generated_token: nil, actor_user: nil, impersonation_session_id: nil)
        super(
          user:,
          token_expires_at:,
          token_source:,
          roles:,
          principal_type:,
          generated_token:,
          actor_user: actor_user || user,
          impersonation_session_id:
        )
      end

      def self.from_authenticate_session_result(data:, metadata:)
        new(
          user: data[:user],
          token_expires_at: data[:token_expires_at],
          token_source: metadata[:token_source],
          roles: data[:user].roles,
          principal_type: :user,
          generated_token: data[:generated_token],
          actor_user: data[:actor_user] || data[:user],
          impersonation_session_id: data[:impersonation_session_id]
        )
      end
    end
  end
end
