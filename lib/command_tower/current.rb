# frozen_string_literal: true

module CommandTower
  class Current < ActiveSupport::CurrentAttributes
    attribute :execution_uuid
    attribute :correlation_id
    attribute :request_id
    attribute :causation_id
    attribute :source
    attribute :user_id
    attribute :originating_administrator_id
    attribute :effective_user_id
    attribute :impersonation_active, default: false
    attribute :impersonation_session_id
    attribute :impersonation_activity_recorded, default: false
    attribute :remote_ip
    attribute :user_agent
  end
end
