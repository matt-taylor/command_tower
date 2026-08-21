# frozen_string_literal: true

module CommandTower
  module Execution
    SOURCES = %i[http job rake console].freeze

    module ContextAccess
      def execution_context
        CommandTower::Current
      end

      def publish_event(category:, name:, payload: {})
        CommandTower::Events.publish(category:, name:, payload:, subject: self.class.name)
      end

      def audit(name, subject: nil, affected_user: nil, changes: {}, metadata: {}, attribution_mode: nil, subject_label: nil, scope_class: :global, host_context: nil)
        CommandTower::Audit::Emit.call(
          name:,
          subject:,
          affected_user:,
          changes:,
          metadata:,
          attribution_mode:,
          subject_label:,
          scope_class:,
          host_context:
        )
      end

      def log_debug(msg)
        publish_event(category: :log, name: :debug, payload: { message: msg.to_s })
      end

      def log_info(msg)
        publish_event(category: :log, name: :info, payload: { message: msg.to_s })
      end

      def log_warn(msg)
        publish_event(category: :log, name: :warn, payload: { message: msg.to_s })
      end

      def log_error(msg)
        publish_event(category: :log, name: :error, payload: { message: msg.to_s })
      end
    end

    module IdentityEnrichment
      module_function

      def from_user(user)
        return if user.nil?

        CommandTower::Current.user_id = user.id
        CommandTower::Current.effective_user_id = user.id
        CommandTower::Current.originating_administrator_id = nil
        CommandTower::Current.impersonation_active = false
        CommandTower::Current.impersonation_session_id = nil
      end

      def from_impersonation_session(session, actor:, target:)
        CommandTower::Current.user_id = target.id
        CommandTower::Current.effective_user_id = target.id
        CommandTower::Current.originating_administrator_id = actor.id
        CommandTower::Current.impersonation_active = true
        CommandTower::Current.impersonation_session_id = session.id
      end
    end
  end

  def self.with_execution(source:, **attrs, &block)
    raise ArgumentError, "block required" unless block

    source = source.to_sym
    unless Execution::SOURCES.include?(source)
      raise ArgumentError, "invalid execution source #{source.inspect} (allowed: #{Execution::SOURCES.join(", ")})"
    end

    return yield if Current.execution_uuid.present?

    execution_uuid = attrs[:execution_uuid].presence || SecureRandom.uuid
    assigned = {
      execution_uuid:,
      correlation_id: attrs[:correlation_id].presence || execution_uuid,
      source:,
      request_id: attrs[:request_id],
      causation_id: attrs[:causation_id],
      user_id: attrs[:user_id],
      originating_administrator_id: attrs[:originating_administrator_id],
      effective_user_id: attrs[:effective_user_id],
      impersonation_active: attrs.key?(:impersonation_active) ? attrs[:impersonation_active] : false,
      impersonation_session_id: attrs[:impersonation_session_id],
      impersonation_activity_recorded: attrs.key?(:impersonation_activity_recorded) ? attrs[:impersonation_activity_recorded] : false,
      remote_ip: attrs[:remote_ip],
      user_agent: attrs[:user_agent]
    }

    run = -> { Current.set(assigned, &block) }

    if execution_wrapper_idle?
      Rails.application.executor.wrap { run.call }
    else
      run.call
    end
  end

  def self.execution_wrapper_idle?
    return true unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

    !Rails.application.executor.active?
  end
end
