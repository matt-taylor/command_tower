# frozen_string_literal: true

class CommandTower::AuditProbeWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(name:, **kwargs)
    audit(name, **kwargs)
    success(payload: { ok: true }, http_status: :ok)
  end
end

class CommandTower::AuditManyFactsWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(facts:)
    facts.each do |fact|
      attrs = fact.to_h.symbolize_keys
      audit(attrs.fetch(:name), **attrs.except(:name))
    end
    success(payload: { ok: true }, http_status: :ok)
  end
end

class CommandTower::AuditProbeService < CommandTower::Services::ApplicationService
  def call
    kwargs = context.audit_kwargs.to_h.symbolize_keys
    audit(context.audit_name, **kwargs)
  end
end

class CommandTower::AuditTransactionalWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(user:, email:, name:, **audit_kwargs)
    transaction do
      user.update!(email:)
      audit(name, subject: user, affected_user: user, **audit_kwargs)
      success(payload: { email: user.email }, http_status: :ok)
    end
  end
end

class CommandTower::AuditTransactionalThenRaiseWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(user:, email:, name:, **audit_kwargs)
    transaction do
      user.update!(email:)
      audit(name, subject: user, affected_user: user, **audit_kwargs)
      raise StandardError, "audit transactional probe"
    end
  end
end

class CommandTower::AuditTwiceTransactionalWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(user:, email:)
    transaction do
      user.update!(email:)
      audit(:password_changed, subject: user, affected_user: user, changes: {})
      audit(:password_changed, subject: user, affected_user: user, changes: {})
      success(payload: { email: user.email }, http_status: :ok)
    end
  end
end

class CommandTower::AuditManyFactsTransactionalWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(user:, email:, facts:)
    transaction do
      user.update!(email:)
      facts.each do |fact|
        attrs = fact.to_h.symbolize_keys
        audit(attrs.fetch(:name), **attrs.except(:name))
      end
      success(payload: { email: user.email }, http_status: :ok)
    end
  end
end

class CommandTower::AuditNestedServiceTransactionalWorkflow < CommandTower::Workflows::ApplicationWorkflow
  retry_strategy :none

  def call(user:, email:, name:, **audit_kwargs)
    transaction do
      user.update!(email:)
      CommandTower::AuditProbeService.call(
        audit_name: name,
        audit_kwargs: { subject: user, affected_user: user }.merge(audit_kwargs)
      )
      success(payload: { email: user.email }, http_status: :ok)
    end
  end
end
